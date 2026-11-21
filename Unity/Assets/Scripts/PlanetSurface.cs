using System;
using System.Collections.Generic;
using System.IO;
using Newtonsoft.Json.Linq;
using UnityEngine;
using UnityEngine.Rendering;

namespace MiniPlanete
{
    public sealed class PlanetSurface
    {
        public readonly Vector3[] Centers;
        public readonly int[][] Neighbors;
        public readonly Transform Root;
        readonly Transform buildings, vegetation;
        readonly Material groundMaterial, waterMaterial;
        readonly Dictionary<string,Mesh> models = new Dictionary<string,Mesh>();
        readonly Dictionary<int,GameObject> structures = new Dictionary<int,GameObject>();
        float[] radii;
        float scale;
        VillageSimulation sim;
        GameObject marker;
        Transform[] birds, people;
        Vector3 birdUp;
        string[] lastModels;
        public PlanetSurface(int frequency, Transform parent)
        {
            Root = Child(parent,"Planet");
            buildings = Child(Root,"Village");
            vegetation = Child(Root,"Woodland");
            using (var r = Reader("Grid"+frequency)) {
                int count = r.ReadInt32(); Centers = new Vector3[count]; Neighbors = new int[count][];
                for (int i=0;i<count;i++) {
                    Centers[i]=ReadVector(r); int k=r.ReadByte(); Neighbors[i]=new int[k];
                    for (int j=0;j<k;j++) Neighbors[i][j]=r.ReadUInt16();
                }
            }
            groundMaterial=new Material(Resources.Load<Shader>("Planet"));
            waterMaterial=new Material(groundMaterial); waterMaterial.SetFloat("_Water",1);
            LoadModels();
            scale=Mathf.Clamp(7.5f/frequency,0.35f,1.2f);
        }
        static Transform Child(Transform parent,string name)
        {
            var t=new GameObject(name).transform; t.SetParent(parent,false); return t;
        }
        static BinaryReader Reader(string id)
        {
            var file=Resources.Load<TextAsset>(id);
            if (!file) throw new InvalidDataException(id);
            Stream input=new MemoryStream(file.bytes);
            if(id=="Village") input=new System.IO.Compression.GZipStream(input,System.IO.Compression.CompressionMode.Decompress);
            return new BinaryReader(input);
        }
        static Vector3 ReadVector(BinaryReader r) => new Vector3(r.ReadSingle(),r.ReadSingle(),r.ReadSingle());
        static Color Hex(string s) { ColorUtility.TryParseHtmlString("#"+s,out var c);return c; }
        static Mesh Make(List<Vector3> v,List<Color32> c,List<int> indices,List<Vector3> normals=null)
        {
            var mesh=new Mesh();
            if(v.Count>65535) mesh.indexFormat=IndexFormat.UInt32;
            mesh.SetVertices(v);mesh.SetColors(c);mesh.SetTriangles(indices,0);
            if(normals==null) mesh.RecalculateNormals(); else mesh.SetNormals(normals);
            mesh.RecalculateBounds();return mesh;
        }
        static GameObject Draw(Transform parent,string name,Mesh mesh,Material material)
        {
            var t=Child(parent,name);
            t.gameObject.AddComponent<MeshFilter>().sharedMesh=mesh;
            t.gameObject.AddComponent<MeshRenderer>().sharedMaterial=material;
            return t.gameObject;
        }
        void LoadModels()
        {
            using(var r=Reader("Village")) {
                int count=r.ReadInt32();
                for(int b=0;b<count;b++) {
                    string name=System.Text.Encoding.UTF8.GetString(r.ReadBytes(r.ReadInt32()));
                    var verts=new List<Vector3>();var norms=new List<Vector3>();var colors=new List<Color32>();var faces=new List<int>();
                    int pieces=r.ReadInt32();
                    for(int p=0;p<pieces;p++) {
                        int size=r.ReadInt32(), indices=r.ReadInt32(), start=verts.Count;
                        var color=new Color32(r.ReadByte(),r.ReadByte(),r.ReadByte(),255);
                        for(int k=0;k<size;k++) { verts.Add(ReadVector(r));norms.Add(ReadVector(r));colors.Add(color); }
                        // Godot front faces are clockwise looking at the surface; Unity's cross-product normal points outside.
                        for(int k=0;k<indices;k+=3) {
                            int a=start+r.ReadUInt16(), mid=start+r.ReadUInt16(), c=start+r.ReadUInt16();
                            if(Vector3.Dot(Vector3.Cross(verts[mid]-verts[a],verts[c]-verts[a]),norms[a])<0) (mid,c)=(c,mid);
                            faces.Add(a);faces.Add(mid);faces.Add(c);
                        }
                    }
                    models[name]=Make(verts,colors,faces,norms);
                }
            }
        }
        public void Create(VillageSimulation game)
        {
            sim=game;int n=Centers.Length; radii=new float[n];lastModels=new string[n];
            var terrainColors=new Color[n];
            for(int i=0;i<n;i++) {
                var id=sim.Terrain[i]; var def=sim.Terrains[id];
                float noise=Mathf.PerlinNoise(Centers[i].x*12+21,Centers[i].z*15+Centers[i].y*4);
                radii[i]=id=="ocean"?0.966f:id=="shallow"?0.986f:
                    1.003f;
                if(id!="ocean" && id!="shallow")
                    radii[i]=1.003f+(float)def["height"]+((float?)def["peak"] ?? 0f)*(0.42f+noise*0.65f);
                terrainColors[i]=Hex((string)def["color"])*Mathf.Lerp(0.87f,1.06f,noise);
            }
            var land=new List<Vector3>();var tint=new List<Color32>();var ind=new List<int>();
            var midpoints=new Dictionary<long,int>();
            for(int i=0;i<n;i++) {land.Add(Centers[i]*radii[i]);tint.Add(terrainColors[i]);}
            int Mid(int a,int b) {
                long key=((long)Math.Min(a,b)<<32)|(uint)Math.Max(a,b);
                if(midpoints.TryGetValue(key,out int idx))return idx;
                Vector3 dir=(land[a].normalized+land[b].normalized).normalized;
                float ridge=0.0025f*(Mathf.PerlinNoise(dir.x*33+45,dir.z*25+dir.y*18)-0.5f);
                idx=land.Count;midpoints[key]=idx;
                land.Add(dir*((land[a].magnitude+land[b].magnitude)*0.5f+ridge));
                tint.Add(Color.Lerp(tint[a],tint[b],0.5f));return idx;
            }
            void Tri(int a,int b,int c) {
                if(Vector3.Dot(Vector3.Cross(land[b]-land[a],land[c]-land[a]),land[a])<0)(b,c)=(c,b);
                ind.Add(a);ind.Add(b);ind.Add(c);
            }
            for(int i=0;i<n;i++) for(int j=0;j<Neighbors[i].Length;j++) {
                int b=Neighbors[i][j],c=Neighbors[i][(j+1)%Neighbors[i].Length];if(i>b||i>c)continue;
                int ab=Mid(i,b),bc=Mid(b,c),ca=Mid(c,i);
                Tri(i,ab,ca);Tri(b,bc,ab);Tri(c,ca,bc);Tri(ab,bc,ca);
            }
            Draw(Root,"Land",Make(land,tint,ind),groundMaterial);
            var water=new List<Vector3>(land.Count);var coast=new List<Color32>();
            foreach(var point in land) {
                water.Add(point.normalized);
                coast.Add(Color.Lerp(Hex("8dc7b8"),Hex("225a76"),Mathf.SmoothStep(0,1,Mathf.Clamp01((1.001f-point.magnitude)/0.035f))));
            }
            Draw(Root,"Ocean",Make(water,coast,ind,water),waterMaterial);
            models["pine"]=Crown(7,new[]{0.16f,0.14f,0.53f,0.23f,0.43f,0.05f},new[]{0f,0.27f,0.28f,0.57f,0.58f,1.05f},new[]{"735441","735441","395c46","3b6246","4d7351","648257"});
            models["leaf"]=Crown(8,new[]{0.13f,0.12f,0.49f,0.58f,0.33f,0.04f},new[]{0f,0.32f,0.41f,0.67f,0.92f,1.02f},new[]{"70523c","70523c","4d6843","608253","82944e","8eaa63"});
            models["person"]=Crown(7,new[]{0.18f,0.21f,0.13f,0.15f,0.04f},new[]{0f,0.50f,0.62f,0.81f,0.88f},new[]{"755442","ba704e","bc895f","edbe96","80573a"});
            models["bird"]=Make(new List<Vector3>{new Vector3(-1,.2f,.2f),Vector3.forward*.35f,Vector3.back*.35f,new Vector3(1,.2f,.2f)},new List<Color32>{Color.gray,Color.white,Color.gray,Color.gray},new List<int>{0,1,2,2,1,3,2,1,0,3,1,2});
            birds=new Transform[7];people=new Transform[12];
            for(int i=0;i<birds.Length;i++)birds[i]=Draw(Root,"Bird",models["bird"],groundMaterial).transform;
            for(int i=0;i<people.Length;i++)people[i]=Draw(Root,"Villager",models["person"],groundMaterial).transform;
            birdUp=Vector3.Cross(Centers[sim.Center],Mathf.Abs(Centers[sim.Center].y)>.9f?Vector3.right:Vector3.up).normalized;
            marker=Draw(Root,"Selection",Crown(32,new[]{1f,1f},new[]{0f,0.045f},new[]{"ffde85","fff1ae"}),groundMaterial);
            marker.SetActive(false); Refresh();
        }

        static Mesh Crown(int sides,float[] radii,float[] heights,string[] tints)
        {
            var v=new List<Vector3>();var colors=new List<Color32>();var ind=new List<int>();
            for(int row=0;row<radii.Length;row++)for(int k=0;k<sides;k++) {
                float a=2*Mathf.PI*k/sides;
                v.Add(new Vector3(Mathf.Sin(a)*radii[row],heights[row],Mathf.Cos(a)*radii[row]));colors.Add(Hex(tints[row]));
                if(row==0)continue;
                int low=(row-1)*sides+k,next=(row-1)*sides+(k+1)%sides;
                ind.AddRange(new[]{low,next,low+sides,next,next+sides,low+sides});
            }
            return Make(v,colors,ind);
        }
        Mesh forest;
        public void Refresh()
        {
            bool treesChanged=forest==null;
            for(int i=0;i<Centers.Length;i++) {
                string id=sim.Placed[i];
                if(!string.IsNullOrEmpty(id))id=!sim.Active(i)?"scaffold":id=="townhall"?"townhall_"+sim.Level:id;
                if(id==lastModels[i])continue;
                if(string.IsNullOrEmpty(lastModels[i])!=string.IsNullOrEmpty(id))treesChanged=true;
                lastModels[i]=id;
                if(structures.TryGetValue(i,out var old)) {UnityEngine.Object.Destroy(old);structures.Remove(i);}
                if(string.IsNullOrEmpty(id))continue;
                var obj=Draw(buildings,id,models[id],groundMaterial);structures.Add(i,obj);
                var t=obj.transform;t.localPosition=Centers[i]*Mathf.Max(1.001f,radii[i]);
                t.localRotation=Quaternion.FromToRotation(Vector3.up,Centers[i])*Quaternion.Euler(0,i*137.5f,0);
                t.localScale=Vector3.one*scale;
            }
            if(!treesChanged)return;
            var instances=new List<CombineInstance>();var rng=new System.Random(unchecked((int)(long)sim.Game["world_seed"]));
            for(int i=0;i<Centers.Length;i++) {
                float choice=(float)rng.NextDouble();
                int count=sim.Terrain[i]=="forest"?4:sim.Terrain[i]=="plains"&&choice<0.32f?1:sim.Terrain[i]=="hills"&&choice<0.5f?1:0;
                for(int k=0;k<count;k++) {
                    int n=Neighbors[i][rng.Next(Neighbors[i].Length)];float t=0.09f+(float)rng.NextDouble()*0.34f;
                    float height=scale*(0.021f+0.022f*(float)rng.NextDouble());
                    if(!string.IsNullOrEmpty(sim.Placed[i]))continue;
                    Vector3 dir=Vector3.Lerp(Centers[i],Centers[n],t).normalized;
                    float r=Mathf.Lerp(radii[i],radii[n],t);if(r<=1.0f)continue;
                    instances.Add(new CombineInstance { mesh=models[sim.Terrain[i]=="hills"||choice<0.43f?"pine":"leaf"],
                        transform=Matrix4x4.TRS(dir*r,Quaternion.FromToRotation(Vector3.up,dir),Vector3.one*height)});
                }
            }
            if(forest!=null)UnityEngine.Object.Destroy(forest);
            forest=new Mesh {indexFormat=IndexFormat.UInt32};forest.CombineMeshes(instances.ToArray(),true,true);
            var filter=vegetation.GetComponent<MeshFilter>();
            if(!filter) {filter=vegetation.gameObject.AddComponent<MeshFilter>();vegetation.gameObject.AddComponent<MeshRenderer>().sharedMaterial=groundMaterial;}
            filter.sharedMesh=forest;
        }
        public void Animate(float time)
        {
            for(int i=0;i<birds.Length;i++) {
                float phase=time*0.09f+i*0.022f;
                var tangent=Quaternion.AngleAxis(phase*Mathf.Rad2Deg,birdUp)*Centers[sim.Center];
                Vector3 dir=(tangent+birdUp*(i%2)*0.018f).normalized;
                birds[i].localPosition=dir*(1.115f+0.004f*Mathf.Sin(time+i));
                birds[i].localRotation=Quaternion.LookRotation(Vector3.Cross(birdUp,dir),dir);
                birds[i].localScale=new Vector3(.011f,.012f*(1+0.7f*Mathf.Sin(time*8+i)),.011f);
            }
            for(int i=0;i<people.Length;i++) {
                var t=people[i];bool active=i<sim.Population;
                if(t.gameObject.activeSelf!=active)t.gameObject.SetActive(active);
                if(!active)continue;
                int neighbor=Neighbors[sim.Center][i%Neighbors[sim.Center].Length];
                float phase=0.32f+0.26f*Mathf.Sin(time*0.38f+i*0.93f);
                var dir=Vector3.Lerp(Centers[sim.Center],Centers[neighbor],phase).normalized;
                t.localPosition=dir*(Mathf.Max(1,Mathf.Lerp(radii[sim.Center],radii[neighbor],phase))+.0007f*Mathf.Abs(Mathf.Sin(time*7+i)));
                t.localRotation=Quaternion.FromToRotation(Vector3.up,dir);t.localScale=Vector3.one*.011f*scale;
            }
        }
        public int Nearest(Vector3 dir)
        {
            int best=0;float dot=-2;
            for(int i=0;i<Centers.Length;i++) {float d=Vector3.Dot(dir,Centers[i]);if(d>dot){best=i;dot=d;}}
            return best;
        }
        public void Mark(int i)
        {
            marker.SetActive(i>=0);if(i<0)return;
            marker.transform.localPosition=Centers[i]*Mathf.Max(1.002f,radii[i]+0.001f);
            marker.transform.localRotation=Quaternion.FromToRotation(Vector3.up,Centers[i]);marker.transform.localScale=Vector3.one*0.034f*scale;
        }
    }
}
