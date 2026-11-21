using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using MiniPlanete;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using UnityEngine;

public sealed class IslandGame : MonoBehaviour
{
    Camera eye;
    PlanetSurface surface;
    VillageSimulation sim;
    JObject strings;
    float distance=2.65f, elapsed, saveTimer, lifeTime;
    Vector2 pressed, previous;
    bool tracking, dragged, confirmRemoval;
    int selected=-1, page;
    string panel="", message="", fatal="";
    GUIStyle title, text, small, button, panelStyle;
    float zoomRatio;
    string SavePath => Path.Combine(Application.persistentDataPath,"unity-village.json");

    static JObject Read(string id) => JObject.Parse(Resources.Load<TextAsset>("Game/"+id).text);
    [RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]
    static void Launch() { new GameObject("Mini Planète").AddComponent<IslandGame>(); }

    void Start()
    {
        try {
            Application.targetFrameRate=60;
            Screen.orientation=ScreenOrientation.Portrait;
            strings=Read(Application.systemLanguage==SystemLanguage.English?"locale/en":"locale/fr");
            string incoming=Path.Combine(Application.persistentDataPath,"savegame.json");
            JObject game;
            double away=0;
            if(File.Exists(SavePath) || File.Exists(SavePath+".bak") || File.Exists(incoming)) {
                string path=File.Exists(SavePath)?SavePath:File.Exists(SavePath+".bak")?SavePath+".bak":incoming;
                JObject file;
                try { file=JObject.Parse(File.ReadAllText(path)); }
                catch(JsonException) when(path==SavePath && File.Exists(path+".bak")) {
                    file=JObject.Parse(File.ReadAllText(path+".bak"));
                }
                if((int?)file["version"]!=1)throw new InvalidDataException(T("UNITY_SAVE_VERSION"));
                game=(JObject)file["game"];
                away=Math.Max(0,(DateTimeOffset.UtcNow.ToUnixTimeSeconds()-(double?)file["saved_at_unix"])??0);
            } else game=JObject.Parse(Resources.Load<TextAsset>("FirstWorld").text);
            surface=new PlanetSurface((int)game["planet"]["frequency"],transform);
            sim=new VillageSimulation(game,Read,surface.Neighbors);
            if((int)game["speed"]>0 && away>0) {
                int offline=(int)(Math.Min(away,3600*(double)sim.Config["offline_progress_cap_hours"])*(double)sim.Config["offline_progress_efficiency"]*(int)sim.Config["tick_rate_hz"]);
                sim.Advance(offline);
            }
            surface.Create(sim);
            surface.Root.rotation=Quaternion.FromToRotation(surface.Centers[sim.Center],Vector3.back);
            eye=new GameObject("Camera").AddComponent<Camera>();eye.tag="MainCamera";
            eye.clearFlags=CameraClearFlags.SolidColor;eye.backgroundColor=new Color(.47f,.69f,.78f);
            eye.nearClipPlane=.012f;eye.farClipPlane=15;
            FrameCamera();
        } catch(Exception e) { fatal=e.Message; Debug.LogException(e); enabled=true; }
    }
    string T(string key) => (string)strings?[key] ?? key;
    void FrameCamera()
    {
        eye.transform.position=new Vector3(0,0,-distance);
        eye.transform.rotation=Quaternion.identity;
        eye.fieldOfView=2*Mathf.Rad2Deg*Mathf.Atan(Mathf.Tan(23*Mathf.Deg2Rad)/eye.aspect);
    }
    void Store()
    {
        if(sim==null || fatal!="")return;
        try {
            var payload=new JObject {["version"]=1,["saved_at_unix"]=DateTimeOffset.UtcNow.ToUnixTimeSeconds(),["game"]=sim.Game};
            string tmp=SavePath+".tmp";File.WriteAllText(tmp,payload.ToString(Formatting.None));
            if(File.Exists(SavePath))File.Replace(tmp,SavePath,SavePath+".bak");else File.Move(tmp,SavePath);
        } catch(IOException e) { message=T("UNITY_SAVE_ERROR");Debug.LogWarning(e.Message); }
    }
    void OnApplicationPause(bool paused) { if(paused)Store(); }
    void OnApplicationQuit() => Store();
    void Update()
    {
        if(sim==null||eye==null||fatal!="")return;
        int speed=(int)sim.Game["speed"];
        elapsed+=Mathf.Min(Time.unscaledDeltaTime,0.5f)*speed*(int)sim.Config["tick_rate_hz"];
        int ticks=(int)elapsed;
        if(ticks>0) {
            int revision=sim.Revision;
            sim.Advance(ticks);elapsed-=ticks;
            if(sim.Revision!=revision)surface.Refresh();
        }
        saveTimer+=Time.unscaledDeltaTime;
        if(saveTimer>=(float)sim.Config["autosave_interval_seconds"]){Store();saveTimer=0;}
        lifeTime+=Time.deltaTime*speed;
        surface.Animate(lifeTime);
        float dayAngle=2*Mathf.PI*(sim.Tick%(int)sim.Config["ticks_per_day"])/(int)sim.Config["ticks_per_day"];
        Shader.SetGlobalVector("_PlanetSun",new Vector3(-Mathf.Cos(dayAngle),.65f,-.72f+.40f*Mathf.Sin(dayAngle)).normalized);
        HandleInput();
    }
    float UiScale => Screen.safeArea.width/390f;
    bool OverHud(Vector2 p)
    {
        Rect safe=Screen.safeArea;
        return panel!="" || !safe.Contains(p) || p.y < safe.yMin+70*UiScale || p.y>safe.yMax-80*UiScale;
    }
    void HandleInput()
    {
        if(Input.touchCount>=2) {
            var a=Input.GetTouch(0);var b=Input.GetTouch(1);tracking=false;
            if(OverHud(a.position)||OverHud(b.position))return;
            float sep=Vector2.Distance(a.position,b.position);
            if(a.phase==TouchPhase.Began||b.phase==TouchPhase.Began)zoomRatio=(distance-1)*sep;
            if(sep>8 && zoomRatio>0)distance=1+Mathf.Clamp(zoomRatio/sep,.23f,3f);
            FrameCamera();return;
        }
        if(Input.mouseScrollDelta.y!=0&&!OverHud(Input.mousePosition)){
            distance=1+Mathf.Clamp((distance-1)*Mathf.Exp(-Input.mouseScrollDelta.y*.16f),.23f,3f);FrameCamera();
        }
        Vector2 p=Input.mousePosition;
        if(Input.GetMouseButtonDown(0)&&!OverHud(p)) {tracking=true;dragged=false;pressed=previous=p;}
        if(!tracking)return;
        if(Input.GetMouseButton(0)) {
            dragged|=Vector2.Distance(p,pressed)>5*UiScale;
            if(dragged) {
                Vector2 delta=(p-previous)/UiScale*(distance-1)*0.21f;
                surface.Root.Rotate(Vector3.up,-delta.x,Space.World);
                surface.Root.Rotate(Vector3.right,delta.y,Space.World);
            }
            previous=p;
        }
        if(Input.GetMouseButtonUp(0)) {
            tracking=false;if(dragged||OverHud(p))return;
            var ray=eye.ScreenPointToRay(p);
            float dot=Vector3.Dot(ray.origin,ray.direction);
            float h=dot*dot-ray.origin.sqrMagnitude+1.014f*1.014f;
            if(h<=0)return;
            Vector3 hit=ray.GetPoint(-dot-Mathf.Sqrt(h));
            selected=surface.Nearest(surface.Root.InverseTransformPoint(hit).normalized);
            surface.Mark(selected);Open("cell");
        }
    }
    void Open(string name) {panel=name;page=0;message="";confirmRemoval=false;}
    void AfterAction()
    {
        sim.CollectGoals();surface.Refresh();Store();message="";
    }
    void Styles()
    {
        if(text!=null)return;
        text=new GUIStyle(GUI.skin.label){fontSize=15,wordWrap=true,alignment=TextAnchor.MiddleLeft};
        text.normal.textColor=new Color(.96f,.95f,.86f);
        title=new GUIStyle(text){fontSize=19,fontStyle=FontStyle.Bold};
        small=new GUIStyle(text){fontSize=13};
        button=new GUIStyle(GUI.skin.button){fontSize=15,wordWrap=true,alignment=TextAnchor.MiddleCenter};
        panelStyle=new GUIStyle(GUI.skin.box){padding=new RectOffset(12,12,8,8)};
    }
    void OnGUI()
    {
        Styles(); Rect safe=Screen.safeArea;float scale=UiScale;if(scale<=0)return;
        GUI.matrix=Matrix4x4.TRS(new Vector3(safe.x,Screen.height-safe.yMax,0),Quaternion.identity,Vector3.one*scale);
        float h=safe.height/scale;
        if(fatal!="") {GUI.Box(new Rect(8,12,374,140),T("UNITY_LOAD_ERROR")+"\n"+fatal);return;}
        if(sim==null)return;
        GUI.Box(new Rect(8,8,374,68),"",panelStyle);
        GUI.Label(new Rect(20,12,350,26),(string)sim.Game["custom"]["planet_name"]+"   ·   "+T("DAY_N").Replace("%d",sim.Day.ToString()),title);
        GUI.Label(new Rect(20,40,356,28),T("RES_FOOD")+" "+(int)sim.Stocks["food"]+"    "+T("RES_WATER")+" "+(int)sim.Stocks["water"]+"    "+T("TAB_PEOPLE")+" "+sim.Population+"/"+sim.Housing,small);
        if(!string.IsNullOrEmpty(sim.EventId)&&panel!="event")Open("event");
        if(panel!="") {
            float ph=Mathf.Min(365,h-148);
            GUILayout.BeginArea(new Rect(8,h-69-ph,374,ph),panelStyle);
            if(panel=="cell")CellPanel();
            if(panel=="village")VillagePanel();
            if(panel=="goals")Goals();
            if(panel=="stocks")StocksPanel();
            if(panel=="event")EventPanel();
            if(message!="")GUILayout.Label(message,small);
            if(panel!="event"&&GUILayout.Button(T("BACK"),button,GUILayout.Height(36)))Open("");
            GUILayout.EndArea();
        } else GUI.Label(new Rect(15,h-102,360,42),T("HINT_DRAG"),small);
        if(GUI.Button(new Rect(8,h-58,91,48),T("VILLAGE_TITLE"),button))Open("village");
        if(GUI.Button(new Rect(103,h-58,90,48),T("NEED_STOCKS"),button))Open("stocks");
        if(GUI.Button(new Rect(197,h-58,94,48),T("TAB_GOALS"),button))Open("goals");
        int speed=(int)sim.Game["speed"];
        if(GUI.Button(new Rect(295,h-58,87,48),speed==0?T("SPEED_PAUSE"):"×"+speed,button)){
            sim.Game["speed"]=speed==0?1:speed==1?2:speed==2?4:0;Store();
        }
    }
    string Name(JToken def) => T((string)def["name_key"]);
    string Price(JToken cost) => cost is JObject obj && obj.Count>0?
        string.Join(" · ",obj.Properties().Select(p=>p.Value+" "+T("RES_"+p.Name.ToUpperInvariant()))):T("FREE");
    void Paging(int count,int perPage)
    {
        if(count<=perPage)return;
        page=Math.Min(page,(count-1)/perPage);
        GUILayout.BeginHorizontal();
        if(GUILayout.Button("‹",button,GUILayout.Height(32)))page=Math.Max(0,page-1);
        GUILayout.Label((page+1)+" / "+((count+perPage-1)/perPage),text);
        if(GUILayout.Button("›",button,GUILayout.Height(32)))page=Math.Min((count-1)/perPage,page+1);
        GUILayout.EndHorizontal();
    }
    void CellPanel()
    {
        string id=sim.Placed[selected];
        GUILayout.Label(Name(sim.Terrains[sim.Terrain[selected]]),title);
        if(!string.IsNullOrEmpty(id)) {
            GUILayout.Label(Name(sim.Buildings[id]),text);
            GUILayout.Label(T((string)sim.Buildings[id]["desc_key"]),small);
            if(!sim.Active(selected))GUILayout.Label(T("UNITY_SITE")+" "+Mathf.CeilToInt((float)sim.Sites[selected.ToString()]["left"]*60)+" s",text);
            string target=(string)sim.Buildings[id]["upgrade_to"];
            if(target!=null && GUILayout.Button(T("UPGRADE").Replace("%s (%s)",Name(sim.Buildings[target])+" · "+Price(sim.Buildings[target]["upgrade_cost"])),button,GUILayout.Height(38))) {
                string error=sim.UpgradeBuilding(selected);if(error=="")AfterAction();else message=T(error);
            }
            if(selected!=sim.Center && GUILayout.Button(T(confirmRemoval?"DEMOLISH_CONFIRM":"DEMOLISH"),button,GUILayout.Height(38))) {
                if(confirmRemoval && sim.Demolish(selected)) { AfterAction();Open(""); }
                else confirmRemoval=true;
            }
            return;
        }
        var items=((JObject)sim.LevelDef["buildings"]).Properties().OrderBy(p=>(int?)sim.Buildings[p.Name]["order"]??0).ToArray();
        Paging(items.Length,3);
        foreach(var item in items.Skip(page*3).Take(3)) {
            string err=sim.BuildError(selected,item.Name);
            if(GUILayout.Button(Name(sim.Buildings[item.Name])+" · "+Price(sim.Buildings[item.Name]["cost"]),button,GUILayout.Height(46))) {
                if(sim.Build(selected,item.Name))AfterAction();else message=T(err);
            }
        }
    }
    void VillagePanel()
    {
        GUILayout.Label(T("TH_LEVEL").Replace("%d / %d",sim.Level+" / "+sim.Levels.Count),title);
        if(sim.Level<sim.Levels.Count && GUILayout.Button(T("TH_UPGRADE")+" · "+Price(sim.Levels[sim.Level]["cost"]),button,GUILayout.Height(40))) {
            if(sim.UpgradeHall())AfterAction();else message=T(sim.HallError());
        }
        var jobs=sim.LevelDef["professions"].Values<string>().ToArray();Paging(jobs.Length,3);
        foreach(string job in jobs.Skip(page*3).Take(3)) {
            var def=sim.Professions[job];
            string label=Name(def)+"  ×"+VillageSimulation.Number(sim.Trained,job)+"   ·   "+Price(def["cost"]);
            if(GUILayout.Button(label,button,GUILayout.Height(40))) {
                if(sim.Train(job))AfterAction();else message=T(sim.TrainError(job));
            }
        }
        if(sim.Training.Count>0)GUILayout.Label(T("TRAINING_ROW").Replace("%s",Name(sim.Professions[(string)sim.Training[0]["profession"]])),small);
    }
    void Goals()
    {
        GUILayout.Label(T("TAB_GOALS"),title);Paging(sim.Objectives.Count,3);
        var done=sim.Game["completed_objectives"].Values<string>().ToList();
        foreach(var g in sim.Objectives.Skip(page*3).Take(3))
            GUILayout.Label((done.Contains((string)g["id"])?"✓  ":"·  ")+T((string)g["title_key"]).Replace("%d",(string)g["value"]),text);
    }
    void StocksPanel()
    {
        GUILayout.Label(T("NEED_STOCKS"),title);
        foreach(var p in sim.Stocks.Properties())
            GUILayout.Label(T("RES_"+p.Name.ToUpperInvariant())+"    "+Math.Floor((double)p.Value),small);
    }
    void EventPanel()
    {
        var e=sim.Events.FirstOrDefault(x=>(string)x["id"]==sim.EventId);if(e==null)return;
        GUILayout.Label(T((string)e["title_key"]),title);GUILayout.Label(T((string)e["text_key"]),small);
        for(int i=0;i<((JArray)e["choices"]).Count;i++)
            if(GUILayout.Button(T((string)e["choices"][i]["label_key"]),button,GUILayout.Height(42))){sim.ResolveEvent(i);AfterAction();Open("");break;}
    }
}
