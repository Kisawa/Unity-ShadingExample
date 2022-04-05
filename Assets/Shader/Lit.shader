Shader "Unlit/Lit"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
		_SSSLut("SSS Lut", 2D) = "white" {}
		_Thickness("Thickness", Range(0, 10)) = 8
		_Intensity("Intensity", Range(0, 5)) = 2
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "Queue"="Geometry" "UniversalMaterialType" = "Lit" }

        Pass
        {
			Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
			#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
			#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
			#pragma multi_compile_fog
            #pragma vertex vert
            #pragma fragment frag
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
			{
				float3 positionOS : POSITION;
				half3 normalOS : NORMAL;
				half4 tangentOS : TANGENT;
				float2 uv : TEXCOORD0;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 positionWS : TEXCOORD1;
				float3 normalWS : TEXCOORD2;
			};

			sampler2D _MainTex;
			sampler2D _SSSLut;
			CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
			float4 _SSSLut_ST;
			half _Thickness;
			half _Intensity;
			CBUFFER_END

            Varyings vert (Attributes input)
            {
                Varyings output;
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);
				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
				output.positionCS = vertexInput.positionCS;
				output.uv = TRANSFORM_TEX(input.uv, _MainTex);
				output.positionWS.xyz = vertexInput.positionWS;
				output.normalWS = normalInput.normalWS;
				output.positionWS.w = ComputeFogFactor(output.positionCS.z);
				return output;
            }

			half3 PreIntegratedSkinWithCurveApprox(half NdotL, half Curvature)
			{
				float curva = (1.0/mad(Curvature, 0.5 - 0.0625, 0.0625) - 2.0) / (16.0 - 2.0);
				float oneMinusCurva = 1.0 - curva;
				float3 curve0;
				{
					float3 rangeMin = float3(0.0, 0.3, 0.3);
					float3 rangeMax = float3(1.0, 0.7, 0.7);
					float3 offset = float3(0.0, 0.06, 0.06);
					float3 t = saturate( mad(NdotL, 1.0 / (rangeMax - rangeMin), (offset + rangeMin) / (rangeMin - rangeMax)  ) );
					float3 lowerLine = (t * t) * float3(0.65, 0.5, 0.9);
					lowerLine.r += 0.045;
					lowerLine.b *= t.b;
					float3 m = float3(1.75, 2.0, 1.97);
					float3 upperLine = mad(NdotL, m, float3(0.99, 0.99, 0.99) -m );
					upperLine = saturate(upperLine);
					float3 lerpMin = float3(0.0, 0.35, 0.35);
					float3 lerpMax = float3(1.0, 0.7 , 0.6 );
					float3 lerpT = saturate( mad(NdotL, 1.0/(lerpMax-lerpMin), lerpMin/ (lerpMin - lerpMax) ));
					curve0 = lerp(lowerLine, upperLine, lerpT * lerpT);
				}
				float3 curve1;
				{
					float3 m = float3(1.95, 2.0, 2.0);
					float3 upperLine = mad( NdotL, m, float3(0.99, 0.99, 1.0) - m);
					curve1 = saturate(upperLine);
				}
				float oneMinusCurva2 = oneMinusCurva * oneMinusCurva;
				return lerp(curve0, curve1, mad(oneMinusCurva2, -1.0 * oneMinusCurva2, 1.0) );
			}

			half3 CalcLight(Light light, float3 normalWS, float curvature)
			{
				half NoL = dot(normalWS, light.direction);
				half halfLambert = saturate(NoL * .5 + .5);

				half3 lightCol = light.color * light.distanceAttenuation * light.shadowAttenuation;
				half3 col = lightCol * NoL;
				half3 sss = (1 - halfLambert) * lightCol * PreIntegratedSkinWithCurveApprox(halfLambert, _Thickness * curvature) * _Intensity;
				//half3 sss = (1 - halfLambert) * lightCol * tex2D(_SSSLut, float2(halfLambert, 1 / (_Thickness * curvature))).xyz * _Intensity;
				return col + sss;
			}

            half4 frag (Varyings input) : SV_Target
            {
                half4 col = tex2D(_MainTex, input.uv);
				float3 normalWS = normalize(input.normalWS);

				//float curvature = col.a;
				float curvature = length(fwidth(normalWS)) / length(fwidth(input.positionWS));

				half3 indirectCol = SampleSH(normalWS);
				Light mainLight = GetMainLight();
			#ifdef _MAIN_LIGHT_SHADOWS
				float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS.xyz);
				mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
			#endif
				half3 lightCol = CalcLight(mainLight, normalWS, curvature);
				
			#if _ADDITIONAL_LIGHTS
				int additionalLightsCount = GetAdditionalLightsCount();
				for(int i = 0; i < additionalLightsCount; i++)
				{
					int perObjectLightIndex = GetPerObjectLightIndex(i);
					Light light = GetAdditionalPerObjectLight(perObjectLightIndex, input.positionWS.xyz);
					light.shadowAttenuation = AdditionalLightRealtimeShadow(perObjectLightIndex, input.positionWS.xyz);
					lightCol += CalcLight(light, normalWS, curvature);
				}
			#endif
				col.xyz *= max(indirectCol, lightCol);
				col.xyz = MixFog(col.xyz, input.positionWS.w);
                return col;
            }
            ENDHLSL
        }

		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode"="ShadowCaster" }
			ZWrite On ZTest LEqual ColorMask 0 Cull Back
			HLSLPROGRAM
			#include "CommonPass.hlsl"
            #pragma vertex ShadowCasterVertex
            #pragma fragment NullFragment
			ENDHLSL
		}

		Pass
		{
			Name "DepthOnly"
			Tags { "LightMode"= "DepthOnly" }
			ZWrite On ZTest LEqual ColorMask 0 Cull Back
			HLSLPROGRAM
			#include "CommonPass.hlsl"
            #pragma vertex DepthOnlyVertex
            #pragma fragment NullFragment
            ENDHLSL
		}
    }
}
