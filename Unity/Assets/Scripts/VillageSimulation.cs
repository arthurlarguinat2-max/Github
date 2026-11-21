using System;
using System.Collections.Generic;
using System.Linq;
using Newtonsoft.Json.Linq;

namespace MiniPlanete
{
    // The save's game object uses the original cell IDs and field names.
    public sealed class VillageSimulation
    {
        public readonly JObject Game, Economy, Buildings, Professions, Terrains, Config;
        public readonly JArray Levels, Objectives, Events;
        public readonly int[][] Neighbors;
        public readonly string[] Terrain, Placed;
        public readonly HashSet<int> Territory = new HashSet<int>();
        readonly List<int> occupied = new List<int>();
        readonly Dictionary<int, int> staffing = new Dictionary<int, int>();
        readonly Random random;
        public int Revision { get; private set; }
        public JObject Stocks => (JObject)Economy["stocks"];
        public JObject Trained => (JObject)Economy["trained"];
        public JObject Sites => (JObject)Economy["construction"];
        public JArray Training => (JArray)Economy["training"];
        public int Center => (int)Economy["village_center"];
        public int Population => (int)Economy["population"];
        public int Level => (int)Economy["townhall_level"];
        public JObject LevelDef => (JObject)Levels[Level - 1];
        public int Tick => (int)Game["tick"];
        public int Day => Tick / (int)Config["ticks_per_day"] + 1;
        public int Housing => (int)LevelDef["housing"] + occupied.Where(i => i != Center && Active(i)).Sum(i => (int?)Buildings[Placed[i]]["housing"] ?? 0);
        public bool Active(int cell) => Sites[cell.ToString()] == null;
        public static double Number(JToken row, string id, double fallback = 0) => (double?)row?[id] ?? fallback;
        static IEnumerable<JProperty> Parts(JToken token) => (token as JObject)?.Properties() ?? Enumerable.Empty<JProperty>();
        public string EventId => (string)Game["pending_event"];
        IEnumerable<JToken> Perks => Levels.Take(Level).SelectMany(l => l["perks"]);
        double PerkFactor(string name) => Perks.Aggregate(1.0,(v,p) => v * Number(p,name,1));
        int BuilderCount => Sites.Count + (Number(Economy,"townhall_upgrade_left",-1) >= 0 ? 1 : 0);

        public VillageSimulation(JObject game, Func<string,JObject> read, int[][] neighbors)
        {
            Game = game;
            Economy = (JObject)game["economy"];
            Config = read("game_config");
            Buildings = (JObject)read("buildings")["buildings"];
            Terrains = (JObject)read("terrains")["terrains"];
            Professions = (JObject)read("professions")["professions"];
            Levels = (JArray)read("townhall")["levels"];
            Events = (JArray)read("events")["events"];
            Objectives = (JArray)read("objectives")["objectives"];
            Neighbors = neighbors;
            Terrain = game["planet"]["terrain"].ToObject<string[]>();
            Placed = game["planet"]["buildings"].ToObject<string[]>();
            if (neighbors.Length != Terrain.Length || Placed.Length != Terrain.Length ||
                Center < 0 || Center >= Terrain.Length || Level < 1 || Level > Levels.Count ||
                Terrain.Any(t => Terrains[t] == null) || Placed.Any(b => !string.IsNullOrEmpty(b) && Buildings[b] == null))
                throw new FormatException("Invalid planet data");
            random = new Random(unchecked((int)(long)Game["world_seed"]) ^ Tick);
            Rebuild();
        }

        void Rebuild()
        {
            occupied.Clear();
            Territory.Clear();
            for (int i = 0; i < Placed.Length; i++)
            {
                if (string.IsNullOrEmpty(Placed[i])) continue;
                occupied.Add(i);
                int radius = (int)Number(i == Center ? LevelDef : Buildings[Placed[i]], "territory", 2);
                radius *= Math.Max(1, (int)Math.Floor((int)Game["planet"]["frequency"] / 8.0 + 0.5));
                var visited = new HashSet<int> { i };
                var queue = new Queue<(int cell,int depth)>();
                queue.Enqueue((i,0));
                while (queue.Count > 0)
                {
                    var here = queue.Dequeue();
                    Territory.Add(here.cell);
                    if (here.depth == radius) continue;
                    foreach (int next in Neighbors[here.cell])
                        if (visited.Add(next)) queue.Enqueue((next,here.depth + 1));
                }
            }
            occupied.Sort((a,b) => {
                int order = Number(Buildings[Placed[a]],"priority",9).CompareTo(Number(Buildings[Placed[b]],"priority",9));
                return order == 0 ? a.CompareTo(b) : order;
            });
            staffing.Clear();
            var free = Parts(Trained).ToDictionary(p => p.Name,p => (int)p.Value);
            foreach (int i in occupied)
            {
                string job = (string)Buildings[Placed[i]]["profession"];
                if (!Active(i) || job == null || !free.TryGetValue(job,out int count)) continue;
                int assigned = Math.Min(count,(int)Number(Buildings[Placed[i]],"workers"));
                staffing[i] = assigned;
                free[job] -= assigned;
            }
            Revision++;
        }
        bool Affordable(JToken cost) => Parts(cost).All(p => Number(Stocks,p.Name) + 0.000001 >= (double)p.Value);
        void Adjust(JToken values, double factor)
        {
            foreach (var p in Parts(values))
                Stocks[p.Name] = Math.Max(0, Number(Stocks,p.Name) + (double)p.Value * factor);
        }
        IEnumerable<int> Around(int cell) { yield return cell; foreach (int n in Neighbors[cell]) yield return n; }
        JToken Deposits(int i) => Game["planet"]["resources"][i];

        public string BuildError(int cell, string id)
        {
            var d = Buildings[id];
            if (d == null || cell < 0 || cell >= Placed.Length || (bool?)d["buildable"] == false) return "BUILD_ERR_UNKNOWN";
            if (!string.IsNullOrEmpty(Placed[cell])) return "BUILD_ERR_OCCUPIED";
            int limit = (int)Number(LevelDef["buildings"],id);
            if (limit == 0) return "BUILD_ERR_LOCKED";
            if (!d["terrains"].Values<string>().Contains(Terrain[cell])) return "BUILD_ERR_TERRAIN";
            string resource = (string)d["extracts"];
            if (resource != null && !Around(cell).Any(n => Number(Deposits(n),resource) > 0)) return "BUILD_ERR_DEPOSIT";
            if (occupied.Count(i => Placed[i] == id) >= limit) return "BUILD_ERR_LIMIT";
            if (!Territory.Contains(cell)) return "BUILD_ERR_TERRITORY";
            if (BuilderCount >= (int)LevelDef["builders"]) return "BUILD_ERR_BUILDERS";
            return Affordable(d["cost"]) ? "" : "BUILD_ERR_COST";
        }
        public bool Build(int cell,string id)
        {
            if (BuildError(cell,id) != "") return false;
            Adjust(Buildings[id]["cost"],-1);
            Place(cell,id);
            return true;
        }
        void Place(int cell, string id)
        {
            double days = Number(Buildings[id],"build_days");
            Placed[cell] = id;
            Game["planet"]["buildings"][cell] = id;
            if (days > 0) Sites[cell.ToString()] = new JObject { ["left"] = days, ["total"] = days };
            Rebuild();
        }
        public string UpgradeBuilding(int cell)
        {
            string target = (string)Buildings[Placed[cell]]["upgrade_to"];
            if (target == null || !Active(cell)) return "TH_ERR_BUSY";
            if (Number(LevelDef["buildings"],target) == 0) return "BUILD_ERR_LOCKED";
            if (occupied.Count(i => Placed[i] == target) >= Number(LevelDef["buildings"],target)) return "BUILD_ERR_LIMIT";
            if (BuilderCount >= (int)LevelDef["builders"]) return "BUILD_ERR_BUILDERS";
            var cost = Buildings[target]["upgrade_cost"];
            if (!Affordable(cost)) return "BUILD_ERR_COST";
            Adjust(cost,-1); Place(cell,target);
            return "";
        }
        public bool Demolish(int cell)
        {
            if (cell == Center || string.IsNullOrEmpty(Placed[cell])) return false;
            Adjust(Buildings[Placed[cell]]["cost"],0.5);
            Sites.Remove(cell.ToString());
            Placed[cell] = "";
            Game["planet"]["buildings"][cell] = "";
            Rebuild(); return true;
        }
        public string TrainError(string id)
        {
            if (!LevelDef["professions"].Values<string>().Contains(id)) return "BUILD_ERR_LOCKED";
            if (Training.Count >= (int)LevelDef["training_slots"]) return "TRAIN_ERR_SLOTS";
            if (Population <= Parts(Trained).Sum(p => (int)p.Value) + Training.Count) return "TRAIN_ERR_NO_VILLAGER";
            return Affordable(Professions[id]["cost"]) ? "" : "BUILD_ERR_COST";
        }
        public bool Train(string id)
        {
            if (TrainError(id) != "") return false;
            Adjust(Professions[id]["cost"],-1);
            Training.Add(new JObject {["profession"]=id, ["left"]=(double)Professions[id]["days"]});
            return true;
        }
        public string HallError()
        {
            if (Level >= Levels.Count) return "TH_ERR_MAX";
            if (Number(Economy,"townhall_upgrade_left",-1) >= 0) return "TH_ERR_BUSY";
            var level = Levels[Level];
            if (Population < Number(level["requires"],"population")) return "TH_ERR_REQUIREMENT";
            if (BuilderCount >= (int)LevelDef["builders"]) return "BUILD_ERR_BUILDERS";
            return Affordable(level["cost"]) ? "" : "BUILD_ERR_COST";
        }
        public bool UpgradeHall()
        {
            if (HallError() != "") return false;
            var next = Levels[Level];
            Adjust(next["cost"],-1);
            Economy["townhall_upgrade_left"] = (double)next["days"];
            return true;
        }
        public void Advance(int ticks)
        {
            int dayTicks = (int)Config["ticks_per_day"];
            while (ticks > 0)
            {
                int count = Math.Min(ticks, Math.Min(dayTicks / 20, dayTicks - Tick % dayTicks));
                Game["tick"] = Tick + count;
                double days = (double)count / dayTicks;
                Work(days);
                Produce(days);
                if (Tick % dayTicks == 0) Daily();
                ticks -= count;
            }
        }
        void Work(double days)
        {
            bool dirty = false;
            double progress = days * PerkFactor("build_speed");
            foreach (var site in Sites.Properties().ToArray())
            {
                double left = Number(site.Value,"left") - progress;
                if (left > 0.0000001) site.Value["left"] = left;
                else { site.Remove(); dirty = true; }
            }
            double hall = Number(Economy,"townhall_upgrade_left",-1);
            if (hall >= 0)
            {
                hall -= progress;
                if (hall <= 0.0000001) { Economy["townhall_level"] = Level + 1; hall = -1; dirty = true; }
                Economy["townhall_upgrade_left"] = hall;
            }
            for (int i = Training.Count - 1; i >= 0; i--)
            {
                var course = Training[i];
                double left = Number(course,"left") - days * PerkFactor("training_speed");
                if (left > 0.0000001) course["left"] = left;
                else {
                    string job = (string)course["profession"];
                    Trained[job] = Number(Trained,job) + 1;
                    Training.RemoveAt(i);
                    dirty = true;
                }
            }
            if (dirty) Rebuild();
        }
        void Produce(double days)
        {
            var wellbeing = Config["economy"]["wellbeing"];
            foreach (int i in occupied)
            {
                var def = Buildings[Placed[i]];
                if (!Active(i) || def["produces"] == null) continue;
                double workers = Number(def,"workers");
                double rate = workers == 0 ? 1 : staffing.TryGetValue(i,out int assigned) ? assigned / workers : 0;
                if (rate == 0) continue;
                rate *= days * (0.6 + 0.006 * Number(Economy,"happiness"));
                if ((bool?)def["fertility_bonus"] == true) rate *= 0.5 + (double)Game["planet"]["fertility"][i];
                if (def["water_bonus"] != null && Neighbors[i].Any(n => (bool?)Terrains[Terrain[n]]["water"] == true))
                    rate *= (double)def["water_bonus"];
                if ((bool?)def["tool_bonus"] == true && Number(Stocks,"tools") > 0)
                    rate *= Number(wellbeing,"tool_bonus",1);
                foreach (var input in Parts(def["consumes"]))
                    rate = Math.Min(rate, Number(Stocks,input.Name) / (double)input.Value);
                Adjust(def["consumes"],-rate);
                foreach (var product in Parts(def["produces"]))
                {
                    double amount = (double)product.Value * rate * Perks.Aggregate(1.0,(v,p) => v * Number(p["production"],product.Name,1));
                    if ((string)def["extracts"] == product.Name) {
                        double remains = amount;
                        foreach (int n in Around(i)) {
                            double available = Number(Deposits(n),product.Name);
                            double take = Math.Min(available,remains);
                            if (take == 0) continue;
                            Deposits(n)[product.Name] = available - take;
                            remains -= take;
                            if (remains <= 0) break;
                        }
                        amount -= remains;
                    }
                    Stocks[product.Name] = Number(Stocks,product.Name) + amount;
                }
            }
            foreach (string resource in new[]{"food","water"})
                Stocks[resource] = Math.Max(0,Number(Stocks,resource) - days * Population * Number(Config["economy"],resource + "_per_person_per_day",1));
            Stocks["tools"] = Math.Max(0,Number(Stocks,"tools") - days * Population * Number(wellbeing,"tool_use_per_day"));
        }
        void Daily()
        {
            var settings = Config["economy"]["wellbeing"];
            bool hungry = Number(Stocks,"food") <= 0, thirsty = Number(Stocks,"water") <= 0;
            foreach (string need in new[]{"health","happiness"})
            {
                double target = Number(settings,need+"_base");
                target += occupied.Where(Active).Sum(i => Number(Buildings[Placed[i]],need) *
                    (Number(Buildings[Placed[i]],"workers") > 0 && !staffing.ContainsKey(i) ? 0 : 1));
                if (hungry) target += Number(settings,"famine_"+need);
                if (thirsty) target += Number(settings,"thirst_"+need);
                double old = Number(Economy,need);
                Economy[need] = old + (Math.Max(0,Math.Min(100,target)) - old) * Number(settings,need+"_speed");
            }
            if (hungry || thirsty || Population > Housing || Number(Economy,"health") < 25 || Number(Economy,"happiness") < 20)
                Economy["population"] = Math.Max(0,Population - (hungry ? Math.Max(1,(int)Math.Ceiling(Population * Number(Config["economy"],"famine_loss"))) : 1));
            else if (Number(Economy,"health") >= 40 && Number(Economy,"happiness") >= 40)
                Economy["population"] = Math.Min(Housing, Population + 1);
            while (Parts(Trained).Sum(p => (int)p.Value) + Training.Count > Population) {
                if (Training.Count > 0) Training.RemoveAt(Training.Count - 1);
                else { var last = Parts(Trained).Last(p => (int)p.Value > 0); Trained[last.Name] = (int)last.Value - 1; }
            }
            for (int i=0;i<Terrain.Length;i++)
                foreach (var regen in Parts(Terrains[Terrain[i]]["regrow"])) {
                    double old = Number(Deposits(i),regen.Name);
                    if (old < (double)regen.Value[1]) Deposits(i)[regen.Name] = Math.Min((double)regen.Value[1],old + (double)regen.Value[0]);
                }
            Rebuild();
            CollectGoals();
            var options = Config["event_settings"];
            if (!string.IsNullOrEmpty(EventId) || Day < Number(options,"first_day") || random.NextDouble() >= Number(options,"daily_chance")) return;
            var eligible = Events.Where(e => Day >= Number(e,"min_day") && Population >= Number(e,"min_population")).ToArray();
            double roll = random.NextDouble() * eligible.Sum(e => Number(e,"weight",1));
            foreach (var e in eligible) if ((roll -= Number(e,"weight",1)) < 0) { Game["pending_event"] = (string)e["id"]; break; }
        }
        public void CollectGoals()
        {
            var done = (JArray)Game["completed_objectives"];
            foreach (var goal in Objectives)
            {
                string id = (string)goal["id"], target = (string)goal["target"];
                if (done.Values<string>().Contains(id)) continue;
                double value;
                switch ((string)goal["type"]) {
                    case "building": value = occupied.Count(i => Placed[i] == target && Active(i)); break;
                    case "buildings_total": value = occupied.Count(Active); break;
                    case "trained": value = Parts(Trained).Sum(p => (int)p.Value); break;
                    case "townhall": value = Level; break;
                    case "day": value = Day; break;
                    case "stock": value = Number(Stocks,(string)goal["res"] ?? target); break;
                    default: value = Number(Economy,(string)goal["type"]); break;
                }
                if (value < (double)goal["value"]) continue;
                Adjust(goal["reward"],1); done.Add(id);
            }
        }
        public void ResolveEvent(int index)
        {
            var e = Events.FirstOrDefault(item => (string)item["id"] == EventId);
            if (e == null || index < 0 || index >= ((JArray)e["choices"]).Count) return;
            foreach (var effect in Parts(e["choices"][index]["effects"])) {
                double value = (double)effect.Value;
                if (effect.Name == "health" || effect.Name == "happiness")
                    Economy[effect.Name] = Math.Min(100,Math.Max(0,Number(Economy,effect.Name)+value));
                else if (effect.Name == "population") Economy["population"] = Math.Max(0,Math.Min(Housing,Population+(int)value));
                else Stocks[effect.Name] = Math.Max(0,Number(Stocks,effect.Name)+value);
            }
            Game["pending_event"] = ""; Rebuild(); CollectGoals();
        }
    }
}
