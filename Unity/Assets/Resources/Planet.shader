Shader "MiniPlanete/Landscape" {
 Properties { _Water("Water surface", Float)=0 }
 SubShader { Tags { "RenderType"="Opaque" }
 Pass {
 CGPROGRAM
 #pragma vertex vert
 #pragma fragment frag
 #include "UnityCG.cginc"
 struct Input {float4 vertex:POSITION; float3 normal:NORMAL; fixed4 color:COLOR;};
 struct Output {float4 position:SV_POSITION; float3 pos:TEXCOORD0; float3 normal:TEXCOORD1; fixed4 color:COLOR; float3 world:TEXCOORD2;};
 float _Water;
 float4 _PlanetSun;
 Output vert(Input v) {
   Output o; o.pos=v.vertex.xyz; o.color=v.color;
   o.normal=UnityObjectToWorldNormal(v.normal);
   o.world=mul(unity_ObjectToWorld,v.vertex).xyz;
   o.position=UnityObjectToClipPos(v.vertex); return o;
 }
 fixed4 frag(Output i):SV_Target {
   float3 n=normalize(i.normal), sun=normalize(_PlanetSun.xyz);
   float light=saturate(dot(n,sun));
   float3 albedo=i.color.rgb;
   if (_Water>0.5) {
     float wave=sin(dot(i.pos,float3(67,39,51))+_Time.y*1.4);
     float rip=sin(dot(i.pos,float3(-93,87,32))-_Time.y*1.8+wave);
     float3 perturb=mul((float3x3)unity_ObjectToWorld,float3(wave,0,rip)*0.045);
     float3 view=normalize(_WorldSpaceCameraPos.xyz-i.world);
     float glint=pow(saturate(dot(normalize(sun+view),normalize(n+perturb))),55.0);
     albedo+=0.23*glint+0.015*(wave+rip);
   }
   return fixed4(albedo*(float3(0.44,0.50,0.56)+light*float3(0.68,0.61,0.49)),1);
 }
 ENDCG
 }
 }
}
