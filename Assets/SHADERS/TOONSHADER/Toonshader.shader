Shader "URP/Toonshader"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _Shades ("Shades", Range(1,10)) = 3

        _OutlineColor ("Outline Color", Color) = (0,0,0,1)
        _OutlineWidth ("Outline Width", Range(0,10)) = 1
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }

        // --------------------------- OUTLINE PASS ---------------------------
        Pass
        {
            Name "Outline"
            Tags { "LightMode"="SRPDefaultUnlit" }

            Cull Front
            ZWrite Off
            ZTest LEqual

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
            };

            float _OutlineWidth;
            float4 _OutlineColor;

            Varyings vert (Attributes v)
            {
                Varyings o;

                float3 normalOS = normalize(v.normalOS);
                float outlineScale = 0.01;

                float3 offset = normalOS * _OutlineWidth * outlineScale;
                float3 positionOS = v.positionOS.xyz + offset;

                o.positionHCS = TransformObjectToHClip(positionOS);
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                return _OutlineColor;
            }
            ENDHLSL
        }

        // --------------------------- TOON PASS ---------------------------
        Pass
        {
            Name "Toon"
            Tags { "LightMode"="UniversalForward" }

            Cull Back
            ZWrite On

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS   : NORMAL;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
            };

            float4 _BaseColor;
            float _Shades;

            Varyings vert (Attributes v)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                return o;
            }

            half4 frag (Varyings i) : SV_Target
            {
                Light mainLight = GetMainLight();
                float NdotL = saturate(dot(normalize(i.normalWS), normalize(mainLight.direction)));

                float toon = floor(NdotL * _Shades) / _Shades;

                return half4(_BaseColor.rgb * toon, 1.0);
            }
            ENDHLSL
        }
    }
}
