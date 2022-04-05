Shader "Unlit/Glass"
{
    Properties
    {
		_ColorMap("Color Map", 2D) = "white"{}
		_Color("Base Color", Color) = (0, 1, 0, 1)
		_GroundColor("Ground Color", Color) = (0, .15, 0, 1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" }

		HLSLINCLUDE
		#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
		#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
		#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
		#pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
		#pragma multi_compile_fragment _ _SHADOWS_SOFT
		#pragma multi_compile_fog
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

		CBUFFER_START(UnityPerMaterial)
		float4 _ColorMap_ST;
		half4 _Color;
		half4 _GroundColor;
		StructuredBuffer<float4> _InstancingPosBuffer;
		CBUFFER_END
		sampler2D _ColorMap;

		struct Attributes
        {
            float4 positionOS : POSITION;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
			half3 color : COLOR;
        };

		float3 CalcPositionWS(float3 pivot, float3 positionOS, float size)
		{
			float3 viewRightWS = UNITY_MATRIX_V[0].xyz;
            float3 viewUpWS = UNITY_MATRIX_V[1].xyz;
            float3 posOS = positionOS.x * viewRightWS;
            posOS += positionOS.y * viewUpWS;
			float3 positionWS = pivot + posOS * size;
			return positionWS;
		}

		half CalcWind(float3 pivot, float positionOS_Y)
		{
			float wind = 0;
            wind += (sin(_Time.y * 4 + pivot.x * .1 + pivot.z * .1) * .25 + .5) * .177;
            wind += (sin(_Time.y * 7.7 + pivot.x * .37 + pivot.z * 3) * .25 + .5) * .025;
            wind += (sin(_Time.y * 11.7 + pivot.x * .77 + pivot.z * 3) * .25 + .5) * .0125;
            wind *= positionOS_Y;
			return wind;
		}

		half3 CalcLight(half3 col, Light light, half3 normalWS, half3 viewWS, half positionOS_Y)
		{
			half3 H = normalize(light.direction + viewWS);
			half halfLambert = dot(normalWS, light.direction) * .5 + .5;
			half NoH = saturate(dot(normalWS, H));
			half specular = pow(NoH, 10) * positionOS_Y * .5;
			half3 lightCol = light.color * light.distanceAttenuation * light.shadowAttenuation;
			half3 res = (col * halfLambert + specular) * lightCol;
			return res;
		}
		ENDHLSL

        Pass
        {
            Tags { "LightMode" = "UniversalForward" }
			Cull Back ZTest Less
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            Varyings vert(Attributes input, uint instanceID : SV_InstanceID)
            {
                Varyings output;
				float4 buffer = _InstancingPosBuffer[instanceID];
				float3 positionWS = CalcPositionWS(buffer.xyz, input.positionOS.xyz, buffer.w);
				half wind = CalcWind(buffer.xyz, input.positionOS.y);
                positionWS.xyz += float3(1, 0, 0) * wind;

                output.positionCS = TransformWorldToHClip(positionWS);

				half3 col = lerp(_GroundColor.rgb, _Color.rgb, input.positionOS.y);
				
			#if _MAIN_LIGHT_SHADOWS
				Light mainLight = GetMainLight(TransformWorldToShadowCoord(positionWS));
			#else
				Light mainLight = GetMainLight();
			#endif
				half3 randomAddToN = (sin(buffer.x * 82.32523 + buffer.z) * .15 + wind * -.25) * UNITY_MATRIX_V[0].xyz;
				half3 normalWS = normalize(half3(0, 1, 0) + randomAddToN + UNITY_MATRIX_V[2].xyz * .5);
				half3 viewWS = normalize(GetWorldSpaceViewDir(positionWS));

				col += CalcLight(col, mainLight, normalWS, viewWS, input.positionOS.y);

			#if _ADDITIONAL_LIGHTS
				int additionalLightsCount = GetAdditionalLightsCount();
				for(int i = 0; i < additionalLightsCount; i++)
				{
					int perObjectLightIndex = GetPerObjectLightIndex(i);
					Light light = GetAdditionalPerObjectLight(perObjectLightIndex, positionWS);
				#if _ADDITIONAL_LIGHT_SHADOWS
					light.shadowAttenuation = AdditionalLightRealtimeShadow(perObjectLightIndex, positionWS);
				#endif
					col += CalcLight(col, light, normalWS, viewWS, input.positionOS.y);
				}
			#endif

				col = MixFog(col, ComputeFogFactor(output.positionCS.z));
				output.color = col;
                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                return half4(input.color, 1);
            }
            ENDHLSL
        }

		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode"="ShadowCaster" }
			ZWrite On ZTest Less ColorMask 0 Cull Back
			HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

			float3 _LightDirection;
			float3 _LightPosition;

			Varyings vert (Attributes input, uint instanceID : SV_InstanceID)
            {
                Varyings output;
				float4 buffer = _InstancingPosBuffer[instanceID];
				float3 positionWS = CalcPositionWS(buffer.xyz, input.positionOS.xyz, buffer.w);
				
				half wind = CalcWind(buffer.xyz, input.positionOS.y);
				half3 randomAddToN = (sin(buffer.x * 82.32523 + buffer.z) * .15 + wind * -.25) * UNITY_MATRIX_V[0].xyz;
				half3 normalWS = normalize(half3(0, 1, 0) + randomAddToN + UNITY_MATRIX_V[2].xyz * .5);

				#if _CASTING_PUNCTUAL_LIGHT_SHADOW
					float3 lightDirectionWS = normalize(_LightPosition - positionWS);
				#else
					float3 lightDirectionWS = _LightDirection;
				#endif

				float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
			#if UNITY_REVERSED_Z
				positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
			#else
				positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
			#endif
				output.positionCS = positionCS;
				output.color = 0;
				return output;
            }

			void frag (Varyings input) { }
			ENDHLSL
		}
    }
}
