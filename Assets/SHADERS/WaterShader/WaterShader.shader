Shader "Custom/WaterShader"
{
    Properties
    {
        _Color("Water Color", Color) = (1,1,1,0.6)
        _EdgeColor("Foam Color", Color) = (1,1,1,1)

        _DepthFactor("Foam Depth Factor", Float) = 1
        _DepthDarkness("Depth Darkness", Float) = 0.5

        _WaveSpeed("Wave Speed", Float) = 1
        _WaveAmp("Wave Amplitude", Float) = 0.2
        _DistortStrength("Distortion Strength", Float) = 1
        _ExtraHeight("Extra Height", Float) = 0

        _MainTex("Main Texture", 2D) = "white" {}
        _NoiseTex("Noise Texture", 2D) = "white" {}
        _DepthRampTex("Depth Ramp", 2D) = "white" {}
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "Queue"="Transparent"
            "RenderType"="Transparent"
        }

        Pass
        {
            Name "WaterURP"
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 screenPos : TEXCOORD1;
            };

            TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
            TEXTURE2D(_NoiseTex);       SAMPLER(sampler_NoiseTex);
            TEXTURE2D(_DepthRampTex);   SAMPLER(sampler_DepthRampTex);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);
            TEXTURE2D(_CameraDepthTexture);  SAMPLER(sampler_CameraDepthTexture);

            float4 _Color;
            float4 _EdgeColor;

            float _DepthFactor;
            float _DepthDarkness;

            float _WaveSpeed;
            float _WaveAmp;
            float _DistortStrength;
            float _ExtraHeight;

            Varyings vert (Attributes IN)
            {
                Varyings OUT;

                float noise = SAMPLE_TEXTURE2D_LOD(
                    _NoiseTex, sampler_NoiseTex, IN.uv, 0).r;

                float3 posWS = TransformObjectToWorld(IN.positionOS.xyz);

                posWS.y += sin(_Time.y * _WaveSpeed * noise) * _WaveAmp + _ExtraHeight;
                posWS.x += cos(_Time.y * _WaveSpeed * noise) * _WaveAmp;

                OUT.positionHCS = TransformWorldToHClip(posWS);
                OUT.screenPos = ComputeScreenPos(OUT.positionHCS);
                OUT.uv = IN.uv;

                return OUT;
            }

            half4 frag (Varyings IN) : SV_Target
            {
                float2 screenUV = IN.screenPos.xy / IN.screenPos.w;

                float noise = SAMPLE_TEXTURE2D(
                    _NoiseTex, sampler_NoiseTex, IN.uv).r;

                screenUV += float2(
                    sin(_Time.y * _WaveSpeed * noise),
                    cos(_Time.y * _WaveSpeed * noise)
                ) * _WaveAmp * _DistortStrength * 0.02;

                half4 background =
                    SAMPLE_TEXTURE2D(_CameraOpaqueTexture,
                                     sampler_CameraOpaqueTexture,
                                     screenUV);

                float rawDepth =
                    SAMPLE_TEXTURE2D(_CameraDepthTexture,
                                     sampler_CameraDepthTexture,
                                     screenUV).r;

                float sceneDepth =
                    LinearEyeDepth(rawDepth, _ZBufferParams);

                float waterDepth =
                    LinearEyeDepth(IN.screenPos.z / IN.screenPos.w,
                                   _ZBufferParams);

                float depthDiff = max(0, sceneDepth - waterDepth);

                float foamLine =
                    saturate(1 - depthDiff * _DepthFactor);

                half3 foamColor =
                    SAMPLE_TEXTURE2D(_DepthRampTex,
                                     sampler_DepthRampTex,
                                     float2(foamLine, 0.5)).rgb
                    * _EdgeColor.rgb;

                half3 albedo =
                    SAMPLE_TEXTURE2D(_MainTex,
                                     sampler_MainTex,
                                     IN.uv).rgb;

                half3 baseColor = (_Color.rgb * albedo);

                half3 waterColor =
                    lerp(baseColor, foamColor, foamLine);

                float depthFade =
                    saturate(depthDiff * _DepthDarkness);

                half3 darkBackground =
                    lerp(background.rgb, waterColor, depthFade);

                half3 composedColor =
                    lerp(darkBackground, waterColor, _Color.a);

                return half4(composedColor, 1);

            }
            ENDHLSL
        }
    }
}
