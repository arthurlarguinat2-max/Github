using System;
using System.IO;
using System.Linq;
using Newtonsoft.Json.Linq;
using MiniPlanete;

static class SimulationChecks
{
    static void Require(bool pass,string message)
    {
        if(!pass) throw new Exception(message);
        Console.WriteLine("OK "+message);
    }
    static int Main(string[] args)
    {
        string root=args[0];
        JObject Data(string id) => JObject.Parse(File.ReadAllText(Path.Combine(root,"Game",id+".json")));
        var g=JObject.Parse(File.ReadAllText(Path.Combine(root,"FirstWorld.json")));
        int[][] neighbors;
        using(var r=new BinaryReader(File.OpenRead(Path.Combine(root,"Grid"+g["planet"]["frequency"]+".bytes")))) {
            neighbors=new int[r.ReadInt32()][];
            for(int i=0;i<neighbors.Length;i++) {
                r.ReadBytes(12);neighbors[i]=new int[r.ReadByte()];
                for(int j=0;j<neighbors[i].Length;j++)neighbors[i][j]=r.ReadUInt16();
            }
        }
        var sim=new VillageSimulation(g,Data,neighbors);
        Require(sim.Population==4 && sim.Placed[sim.Center]=="townhall","original village loaded");
        Require(neighbors.Length==1442 && neighbors.Count(x=>x.Length==5)==12,"original hex sphere");
        Require(neighbors.SelectMany((ns,i)=>ns.Select(n=>neighbors[n].Contains(i))).All(v=>v),"reciprocal neighbours");
        var cell=sim.Territory.First(i=>sim.BuildError(i,"well")=="");
        Require(sim.Build(cell,"well") && !sim.Active(cell),"construction started");
        double stock=(double)sim.Stocks["wood"];
        Require(!sim.Build(cell,"well") && stock==(double)sim.Stocks["wood"],"occupied cell protected");
        Require(sim.Train("water_carrier"),"training started");
        sim.Advance(599);
        Require(sim.Active(cell) && (int)sim.Trained["water_carrier"]==1,"work and training finished");
        sim.Advance(1);
        Require(sim.Day==2 && sim.Game["completed_objectives"].Values<string>().Contains("first_well"),"day and objective rewards");
        var copy=new VillageSimulation(JObject.Parse(g.ToString()),Data,neighbors);
        Require(copy.Tick==sim.Tick && copy.Placed[cell]=="well" && (int)copy.Trained["water_carrier"]==1,"save round trip");
        int goals=((JArray)copy.Game["completed_objectives"]).Count;
        copy.CollectGoals();
        Require(((JArray)copy.Game["completed_objectives"]).Count==goals,"reward idempotency");
        copy.Game["pending_event"]="travelers";copy.ResolveEvent(1);
        Require(copy.EventId=="","event resolution");
        return 0;
    }
}
