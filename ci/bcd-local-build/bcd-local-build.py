#!/usr/bin/env python3
"""Run BCD's GitHub Actions build (.github/workflows/build-ipa.yml) on your own Mac.

BCD (thebcd69/bcd-games, GPL-3.0) has no local build script: its recipe is that workflow, about 900 steps written
for GitHub's macOS runners. This script reads the workflow and runs its build steps one by one in a BCD checkout,
the way the runner would:

  * `run:` steps run with bash (-e -o pipefail), with the workflow's, the job's and the step's `env:`, their
    `working-directory:` and `continue-on-error:`;
  * ${{ ... }} expressions are replaced (github.workspace, env.X, steps.<id>.outputs.<key>, steps.<id>.outcome,
    hashFiles(...), secrets.X = empty), and `if:` conditions are evaluated the same way;
  * $GITHUB_ENV, $GITHUB_OUTPUT and $GITHUB_PATH work as on GitHub, and carry over between steps and between runs;
  * actions/cache/restore answers "no cache" (cache-hit = false), cache/save, checkout and upload-artifact are skipped;
  * the ~650 "Check ..." test steps and the steps that need the owner's secrets (OTA signing, upload) are skipped.

It stops at the first step that fails and tells you how to go on from there; the steps that worked are not run
again. Every step's output is kept in <checkout>/.local-build/logs/.

Usage (from anywhere):
  python3 bcd-local-build.py --repo ~/bcd-lab/bcd-full --list          # number and name of every step, and why one is skipped
  python3 bcd-local-build.py --repo ~/bcd-lab/bcd-full                 # build (goes on from where the last run stopped)
  python3 bcd-local-build.py --repo ~/bcd-lab/bcd-full --from 57       # start again at step 57
  python3 bcd-local-build.py --repo ~/bcd-lab/bcd-full --only 57       # run step 57 alone
  python3 bcd-local-build.py --repo ~/bcd-lab/bcd-full --dry-run       # show what would run, run nothing
  python3 bcd-local-build.py --repo ~/bcd-lab/bcd-full --reset         # forget every finished step

Needs PyYAML: python3 -m pip install --user pyyaml   (or: brew install pyyaml)
The unsigned IPA ends up in <checkout>/build-out/; install it with SideStore, which signs it.
"""
import argparse
import fnmatch
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import time

try:
    import yaml
except ImportError:
    sys.exit("PyYAML is missing: python3 -m pip install --user pyyaml   (or: brew install pyyaml)")

WORKFLOW = ".github/workflows/build-ipa.yml"
SECRET_HINT = re.compile(r"\$\{\{[^}]*secrets\.")


# --------------------------------------------------------------------------- state

class State:
    def __init__(self, repo):
        self.dir = os.path.join(repo, ".local-build")
        self.logs = os.path.join(self.dir, "logs")
        os.makedirs(self.logs, exist_ok=True)
        self.path = os.path.join(self.dir, "state.json")
        self.data = {"done": [], "env": {}, "path": [], "outputs": {}, "outcome": {}}
        if os.path.exists(self.path):
            with open(self.path) as f:
                self.data.update(json.load(f))

    def save(self):
        tmp = self.path + ".tmp"
        with open(tmp, "w") as f:
            json.dump(self.data, f, indent=1)
        os.replace(tmp, self.path)


# --------------------------------------------------------------------------- expressions

def hash_files(repo, patterns):
    files = []
    for p in patterns:
        files += [f for f in glob.glob(os.path.join(repo, p), recursive=True) if os.path.isfile(f)]
    if not files:
        return ""
    h = hashlib.sha256()
    for f in sorted(set(files)):
        with open(f, "rb") as fh:
            h.update(hashlib.sha256(fh.read()).digest())
    return h.hexdigest()


def split_args(s):
    out, cur, q = [], "", False
    for ch in s:
        if ch == "'":
            q = not q
        if ch == "," and not q:
            out.append(cur.strip())
            cur = ""
        else:
            cur += ch
    if cur.strip():
        out.append(cur.strip())
    return [a[1:-1] if len(a) >= 2 and a[0] == a[-1] == "'" else a for a in out]


class Ctx:
    def __init__(self, repo, state, env, failed):
        self.repo, self.state, self.env, self.failed = repo, state, env, failed

    def lookup(self, path):
        parts = path.split(".")
        head = parts[0]
        if head == "github":
            key = parts[1] if len(parts) > 1 else ""
            return {"workspace": self.repo, "run_number": "1", "run_id": "1", "run_attempt": "1",
                    "repository": "thebcd69/madeira-bcd", "ref": "refs/heads/main", "ref_name": "main",
                    "event_name": "workflow_dispatch", "server_url": "https://github.com",
                    "sha": self.env.get("GITHUB_SHA", "")}.get(key, "")
        if head == "env":
            return self.env.get(parts[1], "") if len(parts) > 1 else ""
        if head == "secrets":
            return ""
        if head == "runner":
            return {"os": "macOS", "arch": "ARM64", "temp": self.env.get("RUNNER_TEMP", "")}.get(parts[1] if len(parts) > 1 else "", "")
        if head == "steps" and len(parts) >= 3:
            sid = parts[1]
            if parts[2] == "outputs" and len(parts) >= 4:
                return self.state.data["outputs"].get(sid, {}).get(parts[3], "")
            if parts[2] in ("outcome", "conclusion"):
                return self.state.data["outcome"].get(sid, "")
        if head == "inputs" or head == "matrix" or head == "vars":
            return ""
        return ""

    def evaluate(self, expr):
        """A GitHub Actions expression, evaluated to a Python value (string or bool)."""
        src = expr.strip()
        # functions first
        def fn(m):
            name, args = m.group(1), split_args(m.group(2))
            if name == "hashFiles":
                return repr(hash_files(self.repo, args))
            return m.group(0)
        src = re.sub(r"\b(hashFiles)\(([^()]*)\)", fn, src)
        out, i = [], 0
        tokens = re.finditer(r"'(?:[^']|'')*'|[A-Za-z_][\w\-]*(?:\.[A-Za-z_][\w\-]*)*(?:\(\))?|&&|\|\||==|!=|!|\(|\)|\d+|\s+|.", src)
        for t in tokens:
            s = t.group(0)
            if s.startswith("'"):
                out.append(repr(s[1:-1].replace("''", "'")))
            elif s in ("success()",):
                out.append(repr(not self.failed))
            elif s in ("always()",):
                out.append("True")
            elif s in ("failure()",):
                out.append(repr(bool(self.failed)))
            elif s in ("cancelled()",):
                out.append("False")
            elif s in ("true", "false"):
                out.append("True" if s == "true" else "False")
            elif s == "&&":
                out.append(" and ")
            elif s == "||":
                out.append(" or ")
            elif s == "!":
                out.append(" not ")
            elif re.match(r"[A-Za-z_]", s) and s not in ("and", "or", "not"):
                out.append(repr(self.lookup(s)))
            else:
                out.append(s)
        code = "".join(out)
        try:
            return eval(code, {"__builtins__": {}}, {})
        except Exception as e:  # keep going: an unreadable condition is reported, the step then runs
            print(f"    (could not evaluate '{expr}': {e}; treated as true)")
            return True

    def substitute(self, text):
        if not isinstance(text, str):
            return text
        def rep(m):
            v = self.evaluate(m.group(1))
            if isinstance(v, bool):
                return "true" if v else "false"
            return str(v)
        return re.sub(r"\$\{\{\s*(.*?)\s*\}\}", rep, text)

    def condition(self, cond):
        if cond is None:
            return not self.failed
        c = str(cond).strip()
        m = re.fullmatch(r"\$\{\{\s*(.*?)\s*\}\}", c, re.S)
        if m:
            c = m.group(1)
        uses_status = re.search(r"\b(always|failure|cancelled|success)\(\)", c)
        v = self.evaluate(c)
        ok = bool(v) and v != "false"
        if not uses_status and self.failed:
            return False
        return ok


# --------------------------------------------------------------------------- GITHUB_ENV / GITHUB_OUTPUT

def read_kv_file(path):
    result = {}
    if not os.path.exists(path):
        return result
    with open(path, errors="replace") as f:
        lines = f.read().splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r"^([^=<]+)<<(.+)$", line)
        if m:
            key, delim, buf = m.group(1), m.group(2), []
            i += 1
            while i < len(lines) and lines[i] != delim:
                buf.append(lines[i])
                i += 1
            result[key] = "\n".join(buf)
        elif "=" in line:
            k, v = line.split("=", 1)
            result[k] = v
        i += 1
    return result


# --------------------------------------------------------------------------- steps

def skip_reason(step, with_checks):
    name = step.get("name") or ""
    blob = json.dumps(step)
    if "uses" in step:
        u = step["uses"].split("@")[0]
        if u == "actions/cache/restore":
            return None  # answered with cache-hit=false
        return f"action {u} (not needed locally)"
    if "run" not in step:
        return "no run block"
    if SECRET_HINT.search(blob):
        return "needs the owner's secrets (signing / upload)"
    if name.startswith("Check") and not with_checks:
        return "test step (use --with-checks to run it)"
    return None


def run_step(idx, step, repo, state, wf_env, job_env, failed, dry):
    name = step.get("name") or step.get("uses") or f"step {idx}"
    ctx = Ctx(repo, state, dict(os.environ, **state.data["env"]), failed)
    if not ctx.condition(step.get("if")):
        print(f"[{idx:3}] skip (if: {step.get('if')}) {name}")
        if step.get("id"):
            state.data["outcome"][step["id"]] = "skipped"
        return "skipped"

    if "uses" in step:  # cache restore: no cache here
        if step.get("id"):
            state.data["outputs"].setdefault(step["id"], {})["cache-hit"] = "false"
            state.data["outcome"][step["id"]] = "success"
        print(f"[{idx:3}] cache restore -> no cache ({name})")
        return "success"

    env = dict(os.environ)
    env.update(state.data["env"])
    env["PATH"] = ":".join(state.data["path"] + [env.get("PATH", "")])
    tmp = os.path.join(state.dir, "tmp")
    os.makedirs(tmp, exist_ok=True)
    gh_env, gh_out = os.path.join(tmp, "github_env"), os.path.join(tmp, "github_output")
    gh_path, gh_sum = os.path.join(tmp, "github_path"), os.path.join(tmp, "github_summary")
    for p in (gh_env, gh_out, gh_path):
        open(p, "w").close()
    env.update({"GITHUB_WORKSPACE": repo, "GITHUB_ENV": gh_env, "GITHUB_OUTPUT": gh_out, "GITHUB_PATH": gh_path,
                "GITHUB_STEP_SUMMARY": gh_sum, "GITHUB_REPOSITORY": "thebcd69/madeira-bcd", "GITHUB_RUN_NUMBER": "1",
                "GITHUB_RUN_ID": "1", "GITHUB_ACTIONS": "true", "CI": "true", "RUNNER_OS": "macOS",
                "RUNNER_ARCH": "ARM64", "RUNNER_TEMP": tmp, "GITHUB_SERVER_URL": "https://github.com"})
    for scope in (wf_env, job_env, step.get("env") or {}):
        for k, v in scope.items():
            ctx.env = env
            env[k] = str(ctx.substitute(str(v)))
    ctx.env = env
    script = ctx.substitute(step["run"])
    cwd = os.path.join(repo, ctx.substitute(step.get("working-directory") or "."))
    log = os.path.join(state.logs, f"{idx:03d}.log")

    print(f"[{idx:3}] RUN  {name}")
    if dry:
        return "success"
    t0 = time.time()
    shell = ["bash", "--noprofile", "--norc", "-eo", "pipefail", "-c", script]
    with open(log, "w") as lf:
        lf.write(f"# step {idx}: {name}\n# cwd: {cwd}\n\n{script}\n\n# ---- output ----\n")
        lf.flush()
        p = subprocess.Popen(shell, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        tail = []
        for raw in p.stdout:
            line = raw.decode(errors="replace")
            lf.write(line)
            tail = (tail + [line])[-40:]
            if line.startswith(("::error", "::warning", "::notice")):
                print("      " + line.rstrip()[:300])
        rc = p.wait()
    dt = time.time() - t0

    state.data["env"].update(read_kv_file(gh_env))
    if step.get("id"):
        state.data["outputs"].setdefault(step["id"], {}).update(read_kv_file(gh_out))
    if os.path.exists(gh_path):
        with open(gh_path) as f:
            for line in f.read().splitlines():
                if line.strip() and line.strip() not in state.data["path"]:
                    state.data["path"].insert(0, line.strip())

    outcome = "success" if rc == 0 else "failure"
    if step.get("id"):
        state.data["outcome"][step["id"]] = outcome
    if rc != 0:
        print(f"      FAILED (exit {rc}, {dt:.0f} s) -- log: {log}")
        print("      ---- last lines ----")
        for line in tail[-25:]:
            print("      " + line.rstrip()[:300])
        if step.get("continue-on-error"):
            print("      (continue-on-error: going on, as on GitHub)")
            return "soft-failure"
        return "failure"
    print(f"      ok ({dt:.0f} s)")
    return "success"


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--repo", required=True, help="the BCD checkout (with its submodules)")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--from", dest="start", type=int)
    ap.add_argument("--only", type=int)
    ap.add_argument("--reset", action="store_true")
    ap.add_argument("--with-checks", action="store_true")
    a = ap.parse_args()

    repo = os.path.abspath(os.path.expanduser(a.repo))
    wf_path = os.path.join(repo, WORKFLOW)
    if not os.path.exists(wf_path):
        sys.exit(f"{wf_path} not found: --repo must be the root of a BCD checkout")
    wf = yaml.safe_load(open(wf_path))
    job = wf["jobs"]["build"]
    steps = job["steps"]
    state = State(repo)
    if a.reset:
        state.data = {"done": [], "env": {}, "path": [], "outputs": {}, "outcome": {}}
        state.save()
        print("state cleared")
        return

    if a.list:
        for i, s in enumerate(steps):
            r = skip_reason(s, a.with_checks)
            mark = "done" if i in state.data["done"] else ("skip" if r else "    ")
            print(f"{i:3} {mark} {s.get('name') or s.get('uses')}" + (f"   [{r}]" if r else ""))
        return

    wf_env, job_env = wf.get("env") or {}, job.get("env") or {}
    indices = [a.only] if a.only is not None else list(range(a.start or 0, len(steps)))
    failed = False
    for i in indices:
        s = steps[i]
        if a.only is None and a.start is None and i in state.data["done"]:
            continue
        r = skip_reason(s, a.with_checks)
        if r:
            continue
        res = run_step(i, s, repo, state, wf_env, job_env, failed, a.dry_run)
        if res in ("success", "skipped", "soft-failure") and not a.dry_run:
            if i not in state.data["done"]:
                state.data["done"].append(i)
        state.save()
        if res == "failure":
            failed = True
            # GitHub runs the steps marked if: failure() / always() after a failure; they only print diagnostics,
            # so they are left out here: their messages hid the step that really failed.
            state.save()
            name = s.get("name") or f"step {i}"
            log = os.path.join(state.logs, f"{i:03d}.log")
            print("\n" + "=" * 70)
            print(f"STOPPED AT STEP {i}: {name}")
            print(f"log: {log}")
            print("Send Claude a screenshot of this box and of:  tail -40 " + log)
            print(f"Then run again from this step:  --from {i}")
            print("=" * 70)
            sys.exit(1)
    if not a.dry_run:
        print("\nAll steps done. The unsigned IPA is in", os.path.join(repo, "build-out"))
        for f in sorted(glob.glob(os.path.join(repo, "build-out", "*.ipa"))):
            print("  ", f)


if __name__ == "__main__":
    main()
