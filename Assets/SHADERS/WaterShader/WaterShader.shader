Shader "Custom/Water_URP_Final"
{
    Properties
    {
        _Color ("Color", Color) = (0.2,0.5,1,1)
        _EdgeColor ("Edge Color", Color) = (1,1,1,1)
        _DepthFactor ("Depth Factor", Float) = 1
        _WaveSpeed ("Wave Speed", Float) = 1
        _WaveAmp ("Wave Amp", Float) = 0.2
        _ExtraHeight ("Extra Height", Float) = 0
        _DepthRampTex ("Depth Ramp", 2D) = "white" {}
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _MainTex ("Main Texture", 2D) = "white" {}
        _DistortStrength ("Distort Strength", Float) = 0.05
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "Queue"="Transparent"
            "RenderType"="Transparent"
        }

        Pass
        {
            Name "Forward"
            Tags { "LightMode"="UniversalForward" }

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"

            TEXTURE2D(_NoiseTex); SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_MainTex);  SAMPLER(sampler_MainTex);
            TEXTURE2D(_DepthRampTex); SAMPLER(sampler_DepthRampTex);

            float4 _Color;
            float4 _EdgeColor;
            float _DepthFactor;
            float _WaveSpeed;
            float _WaveAmp;
            float _ExtraHeight;
            float _DistortStrength;

            struct Attributes
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;

                float noise = SAMPLE_TEXTURE2D_LOD(_NoiseTex, sampler_NoiseTex, IN.uv, 0).r;

                float3 pos = IN.positionOS;
                pos.y += sin(_Time.y * _WaveSpeed * noise) * _WaveAmp + _ExtraHeight;
                pos.x += cos(_Time.y * _WaveSpeed * noise) * _WaveAmp;

                OUT.positionHCS = TransformObjectToHClip(pos);
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                OUT.uv = IN.uv;

                return OUT;
            }

            half4 frag(Varyings IN) : SV_Target
            {
                float2 uvScreen = IN.screenPos.xy / IN.screenPos.w;

                // Distorsión del fondo
                float noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, IN.uv).r;
                float2 distortUV = uvScreen + (noise - 0.5) * _DistortStrength;

                // Fondo de la escena
                float3 background = SampleSceneColor(distortUV);

                // Depth
                float sceneDepth01 = SampleSceneDepth(uvScreen);
                float sceneDepth = LinearEyeDepth(sceneDepth01, _ZBufferParams);
                float waterDepth = LinearEyeDepth(IN.positionHCS.z / IN.positionHCS.w, _ZBufferParams);

                // Intensidad de espuma alrededor del objeto
                float foam = saturate(_DepthFactor * (sceneDepth - waterDepth));

                // Agua
                float3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv).rgb;
                float3 waterTint = _Color.rgb * albedo;

                // Espuma con color editable
                float3 foamColor = _EdgeColor.rgb;

                // --- Agua sobre fondo --- 
                // Usamos lerp para que el agua tiña el fondo sin apagarlo
                float blendAmount = 0.5; // cuánto el agua afecta el fondo
                float3 baseWater = lerp(background, waterTint, blendAmount);

                // --- Oscurecer fondo según profundidad ---
                float depthMask = saturate(sceneDepth - waterDepth); // 0 = superficie, 1 = profundo
                float darknessAmount = 0.7; // cuánto oscurece el fondo al máximo
                baseWater = lerp(baseWater, baseWater * 0, depthMask * darknessAmount);

                // --- Añadir espuma encima ---
                float foamStrength = 0.5;
                float3 finalWater = lerp(baseWater, foamColor, foam * foamStrength);

                return half4(finalWater, 1);
            }
            ENDHLSL
        }
    }
}