Shader "Environment/Plane"
{
    Properties
    {
		_Color ("Color", Color) = (1, 1, 1, 1)
        _MainTex ("Texture", 2D) = "white" {}
		_Hardness("Hardness", Range(0, 5)) = 1.5
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "RenderPipeline" = "UniversalPipeline" "Queue"="Transparent" "UniversalMaterialType" = "Lit" }

        Pass
        {
			Tags { "LightMode" = "UniversalForward" }
			Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma vertex vert
            #pragma fragment frag
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
			{
				float3 positionOS : POSITION;
				half3 normalOS : NORMAL;
				float2 uv : TEXCOORD0;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float4 uv : TEXCOORD0;
				float3 positionWS : TEXCOORD1;
				float3 normalWS : TEXCOORD2;
			};

			sampler2D _MainTex;
			CBUFFER_START(UnityPerMaterial)
			half4 _Color;
            float4 _MainTex_ST;
			half _Hardness;
			CBUFFER_END

            Varyings vert (Attributes input)
            {
                Varyings output;
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);
				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
				output.positionCS = vertexInput.positionCS;
				output.uv.xy = TRANSFORM_TEX(input.uv, _MainTex);
				output.uv.zw = input.uv;
				output.positionWS = vertexInput.positionWS;
				output.normalWS = normalInput.normalWS;
				return output;
            }

			half3 CalcMainLight(Light light, float3 normalWS, float3 positionWS)
			{
				half NoL = dot(normalWS, light.direction);
				half3 lightCol = light.color * light.distanceAttenuation * light.shadowAttenuation;
				half3 col = lightCol * NoL;
				return col;
			}

            half4 frag (Varyings input) : SV_Target
            {
                half4 col = tex2D(_MainTex, input.uv.xy) * _Color;
				float3 normalWS = normalize(input.normalWS);
				Light mainLight = GetMainLight();
			#ifdef _MAIN_LIGHT_SHADOWS
				float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
				mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
			#endif
				half3 lightCol = CalcMainLight(mainLight, normalWS, input.positionWS);
				col.xyz *= lightCol;
				float res = pow(1 - saturate(distance(input.uv.zw, float2(.5, .5)) * 2), max(_Hardness, .001));
				col.w = lerp(0, 1, res);
                return col;
            }
            ENDHLSL
        }
    }
}
