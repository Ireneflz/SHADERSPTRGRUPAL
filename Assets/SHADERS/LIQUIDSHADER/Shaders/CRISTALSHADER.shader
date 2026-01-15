Shader "Unlit/CRISTALSHADER"
{
    Properties
    {
        _Color ("Crystal Color", Color) = (0.7, 0.9, 1, 0.4)
        _MainTex ("Texture (optional)", 2D) = "white" {}
        _FresnelPower ("Fresnel Power", Range(0.1, 5)) = 2
        _FresnelIntensity ("Fresnel Intensity", Range(0, 2)) = 1
        _Distortion ("Distortion Amount", Range(0, 0.1)) = 0.02
    }

    SubShader
    {
        Tags 
        { 
            "Queue"="Transparent"
            "RenderType"="Transparent"
        }

        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Back

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewDir : TEXCOORD1;
                float3 normal : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float4 _Color;
            float _FresnelPower;
            float _FresnelIntensity;
            float _Distortion;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.viewDir = normalize(_WorldSpaceCameraPos - worldPos);
                o.normal = UnityObjectToWorldNormal(v.normal);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float fresnel = pow(1.0 - saturate(dot(i.viewDir, i.normal)), _FresnelPower);
                fresnel *= _FresnelIntensity;

                float2 distortedUV = i.uv + i.normal.xy * _Distortion;
                fixed4 tex = tex2D(_MainTex, distortedUV);

                fixed4 col = _Color * tex;
                col.rgb += fresnel;
                col.a = _Color.a;

                return col;
            }
            ENDCG
        }
    }
}
