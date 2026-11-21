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
     // Sample waves in planet space so they wrap around both poles without a UV seam.
     float3 p = normalize(i.pos);
     float time = _Time.y;
     float swell = sin(dot(p, float3(24, 16, -31)) - time * 0.85);
     float ripple = sin(dot(p, float3(-46, 37, 22)) + time * 1.25 + swell * 0.55);
     float3 slope = float3(0.048, 0.032, -0.062) * swell
                  + float3(-0.046, 0.037, 0.022) * ripple;
     float3 tangentSlope = slope - p * dot(p, slope);
     float3 waterNormal = normalize(n + mul((float3x3)unity_ObjectToWorld, tangentSlope)
                                    / max(length(mul((float3x3)unity_ObjectToWorld, p)), 0.0001));
     float3 view = normalize(_WorldSpaceCameraPos.xyz - i.world);
     float fresnel = pow(1.0 - saturate(dot(waterNormal, view)), 3.0);
     float reflection = saturate(dot(reflect(-sun, waterNormal), view));
     float glint = pow(reflection, 32.0) * smoothstep(0.0, 0.2, dot(n, sun));
     albedo = lerp(albedo, float3(0.48, 0.67, 0.76), fresnel * 0.55);
     // The baked water tint interpolates from deep blue (red 34) to shallows (red 141).
     float shallows = saturate((i.color.r * 255.0 - 34.0) / 107.0);
     float wash = sin(shallows * 22.0 - time * 1.6 + swell * 0.8);
     float foam = smoothstep(0.67, 0.97, shallows) * smoothstep(0.40, 0.92, wash);
     albedo = lerp(albedo, float3(0.81, 0.90, 0.85), foam * 0.58);
     albedo += float3(1.0, 0.92, 0.75) * glint * 0.52;
     light = saturate(dot(waterNormal, sun));
   }
   return fixed4(albedo*(float3(0.44,0.50,0.56)+light*float3(0.68,0.61,0.49)),1);
 }
 ENDCG
 }
 }
}
