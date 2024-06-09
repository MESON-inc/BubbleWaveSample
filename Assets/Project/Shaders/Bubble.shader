Shader "Unlit/Bubble"
{
    Properties
    {
        _F0("F0", Range(0, 1)) = 0.02
        _RimLightIntensity ("RimLight Intensity", Float) = 1.0
        _RimLightWidth ("RimLight Width", Range(0, 1)) = 0.5
        _CenterVector ("Center Vector", Vector) = (1, 1, 1, 0)
        _MaskDistance ("Mask Distance", Range(0, 1)) = 0.0
        _ReverseMaskDistance ("Reverse Mask Distance", Range(0, 1)) = 0.0
        _RimLightColor ("RimLightColor", Color) = (1, 1, 1, 1)
        _Color1 ("Color1", Color) = (0.83333333, 0.73607843, 0.93137255, 1)
        _Color2 ("Color2", Color) = (0.93333333, 0.60392157, 0, 1)
        _Color3 ("Color3", Color) = (0.06666667, 0.82352941, 0.92941176, 1)
        _Color4 ("Color4", Color) = (0.01176471, 0.18431373, 0.94509804, 1)
        _Radius ("Radius", Float) = 1
        _WaveRatio ("Wave Ratio", Float) = 10
        _WaveSize ("Wave Size", Float) = 0.15
    }

    SubShader
    {
        Tags
        {
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }

        LOD 100

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #define PI 3.14159265359

            #include "UnityCG.cginc"
            #include "./PerlinNoise.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD1;
                float4 tangent : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
                float3 lightDir : TEXCOORD4;
                half fresnel : TEXCOORD5;
                half3 reflDir : TEXCOORD6;
                float objectY : TEXCOORD7;
                float3 localPos : TEXCOORD8;
            };

            float _F0;
            float _RimLightIntensity;
            float _RimLightWidth;
            float4 _CenterVector;
            half4 _RimLightColor;
            half4 _Color1;
            half4 _Color2;
            half4 _Color3;
            half4 _Color4;
            float _Radius;
            float _WaveRatio;
            float _WaveSize;
            float _MaskDistance;
            float _ReverseMaskDistance;

            float3 applyWave(float3 v, float3 center)
            {
                float3 position = normalize(v);

                float t = dot(position, center);
                float p = acos(t);
                float distance = p * _Radius;
                float normalizedDistance = distance / (2.0 * PI * _Radius);

                float width = 0.1;

                float begin = _MaskDistance - width;
                float end = begin + width;
                float mask = 1.0 - smoothstep(begin, end, normalizedDistance);

                float rbegin = _ReverseMaskDistance - width;
                float rend = rbegin + width;
                float rmask = smoothstep(rbegin, rend, normalizedDistance);

                float rad = distance * _WaveRatio - _Time.w;
                float influence = 1.0 - smoothstep(0, 0.3, normalizedDistance);
                float s = sin(rad) * _WaveSize * influence;
                s *= s;
                float mm = s * (mask * rmask);

                return v + v * mm;
            }

            v2f vert(appdata v)
            {
                v2f o;

                // 初期の頂点位置を保持しておく

                o.localPos = v.vertex.xyz;

                // --------------------------------------------------
                // 波打つ表現のための頂点移動とマスク処理

                float3 center = normalize(_CenterVector.xyz);;
                v.vertex.xyz = applyWave(v.vertex.xyz, center);

                o.uv = v.uv;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = v.normal;
                o.tangent = v.tangent;
                o.objectY = v.vertex.y;

                o.viewDir  = normalize(ObjSpaceViewDir(v.vertex));
                o.lightDir = normalize(ObjSpaceLightDir(v.vertex));
                
                float3 halfDir = normalize(o.viewDir + o.lightDir);
                o.fresnel = _F0 + (1.0h - _F0) * pow(saturate(1.0h - dot(o.viewDir, halfDir)), 5.0);
                o.reflDir = mul(unity_ObjectToWorld, reflect(-o.viewDir, v.normal.xyz));

                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // --------------------------------------------------------------
                // ドーム表面のエフェクトのUV位置を拡大して調整する

                i.uv *= 8.5;

                // --------------------------------------------------------------
                // 色のブレンド処理

                fixed4 col = 0.0;
                float d1 = fbm(i.uv + _Time.xy * 0.22, 2);
                float d2 = fbm(i.uv - _Time.xy * 0.33, 2);
                float d3 = fbm(i.uv + _Time.xy * 0.40, 2);


                float t1 = smoothstep(0.1, 0.35, d1 * d2);
                float t2 = smoothstep(0.1, 0.25, d1 * d3);
                float t3 = smoothstep(0.1, 0.25, d2 * d3);

                col = lerp(_Color1, _Color2, t1);
                col = lerp(col, _Color3, t2);
                col = lerp(col, _Color4, t3);

                // --------------------------------------------------------------
                // 波を適用したあとの形の法線を計算

                float3 bioNormal = normalize(cross(i.normal, i.tangent.xyz));
                float3 center = normalize(_CenterVector.xyz);;

                float eps = 0.00001;
                float3 vertex = applyWave(i.localPos.xyz, center);
                float3 tangentVert = applyWave(i.localPos.xyz + i.tangent * eps, center);
                float3 bioNormalVert = applyWave(i.localPos.xyz + bioNormal * eps, center);

                float3 localTangentVert = normalize(tangentVert - vertex);
                float3 localBioNormalVert = normalize(bioNormalVert - vertex);
                float3 localNormal = cross(localTangentVert, localBioNormalVert);

                float3 normal = localNormal;

                // --------------------------------------------------------------
                // 反射、リムライトの計算

                float NdotL = dot(normal, i.lightDir);
                float3 localRefDir = -i.lightDir + (2.0 * normal * NdotL);
                float spec = pow(max(0, dot(i.viewDir, localRefDir)), 10.0);

                float rimlight = 1.0 - dot(normal, i.viewDir);
                rimlight = smoothstep(0.0, _RimLightWidth, pow(rimlight, 1.5));

                col += rimlight * _RimLightColor * _RimLightIntensity;
                col += spec;

                float3 halfVector = normalize(i.lightDir + i.viewDir);
                float diff = max(0.5, dot(normal, halfVector));
                col.rgb *= diff;

                col.a *= pow(rimlight, 1.5);
                col.a *= saturate(pow(i.objectY, 1.2));
                col.a *= i.fresnel;

                return col;
            }
            ENDCG
        }
    }
}