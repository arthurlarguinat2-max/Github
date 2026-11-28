/* dowser-shim: stands in for Paradox's Launcher\dowser.exe and starts the game one folder up instead.
 *
 * Cities: Skylines II on BCD (iPhone): Steam's launch entry is Launcher\dowser.exe, which installs the Paradox
 * Launcher; that installer hangs under BCD. Started without Steam, Cities2.exe runs but SteamAPI.Init fails.
 * Put this program in place of Launcher\dowser.exe (keep the original as dowser.original.exe): Steam starts it as
 * usual, so the game it starts inherits Steam's environment, and Cities2.exe runs from the game folder.
 *
 * The game's name can be changed with a file "dowser-shim.txt" next to this program (one line, e.g. ..\Cities2.exe).
 */
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wchar.h>

static const WCHAR *skip_program_name(const WCHAR *cl)
{
    if (*cl == L'"') { cl++; while (*cl && *cl != L'"') cl++; if (*cl) cl++; }
    else while (*cl && *cl != L' ' && *cl != L'\t') cl++;
    while (*cl == L' ' || *cl == L'\t') cl++;
    return cl;
}

int WINAPI wWinMain(HINSTANCE inst, HINSTANCE prev, PWSTR args, int show)
{
    WCHAR self[MAX_PATH], dir[MAX_PATH], target[MAX_PATH] = L"..\\Cities2.exe", full[MAX_PATH], workdir[MAX_PATH], cfg[MAX_PATH];
    static WCHAR cmd[32768];
    STARTUPINFOW si;
    PROCESS_INFORMATION pi;
    DWORD code = 1, n;
    WCHAR *slash;
    HANDLE f;
    (void)inst; (void)prev; (void)args; (void)show;
    ZeroMemory(&si, sizeof(si));
    si.cb = sizeof(si);

    if (!GetModuleFileNameW(NULL, self, MAX_PATH)) return 1;
    lstrcpyW(dir, self);
    if (!(slash = wcsrchr(dir, L'\\'))) return 1;
    slash[1] = 0;

    /* optional override: dowser-shim.txt next to this program */
    lstrcpyW(cfg, dir); lstrcatW(cfg, L"dowser-shim.txt");
    f = CreateFileW(cfg, GENERIC_READ, FILE_SHARE_READ, NULL, OPEN_EXISTING, 0, NULL);
    if (f != INVALID_HANDLE_VALUE)
    {
        char buf[MAX_PATH] = {0};
        if (ReadFile(f, buf, MAX_PATH - 1, &n, NULL) && n)
        {
            char *e = buf; while (*e && *e != '\r' && *e != '\n') e++; *e = 0;
            if (buf[0]) MultiByteToWideChar(CP_UTF8, 0, buf, -1, target, MAX_PATH);
        }
        CloseHandle(f);
    }

    lstrcpyW(full, dir); lstrcatW(full, target);
    if (!GetFullPathNameW(full, MAX_PATH, full, NULL)) return 1;
    lstrcpyW(workdir, full);
    if ((slash = wcsrchr(workdir, L'\\'))) *slash = 0;

    /* "<game>" followed by the arguments Steam gave us */
    lstrcpyW(cmd, L"\""); lstrcatW(cmd, full); lstrcatW(cmd, L"\" ");
    lstrcatW(cmd, skip_program_name(GetCommandLineW()));

    if (!CreateProcessW(full, cmd, NULL, NULL, FALSE, 0, NULL, workdir, &si, &pi))
    {
        WCHAR msg[MAX_PATH + 64];
        lstrcpyW(msg, L"dowser-shim could not start:\n"); lstrcatW(msg, full);
        MessageBoxW(NULL, msg, L"dowser-shim", MB_OK | MB_ICONERROR);
        return 1;
    }
    CloseHandle(pi.hThread);
    WaitForSingleObject(pi.hProcess, INFINITE);
    GetExitCodeProcess(pi.hProcess, &code);
    CloseHandle(pi.hProcess);
    return (int)code;
}
