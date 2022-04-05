Shader "Unlit/Furry"
{
    Properties
    {
		_ColorTint("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex ("Texture", 2D) = "white" {}
		_FurryLayerMap("Furry Layer Map", 2D) = "white" {}
		_FurryThickness("Furry Thickness", Range(1, 3)) = 2
		_Translucent("Translucent", Range(0, 3)) = 1
		[Space(10)]
		[Header(Specular)]
		[HDR]_SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
		[Space(5)]
		_Fresnel("Fresnel", Range(0, 5)) = .5
		_RimStrength("Rim Strength", Range(0, 3)) = .5
		[Space(5)]
		_AnisotropicMask("Anisotropic Mask", 2D) = "white" {}
		[Header(With Albedo Color)]
		_AnisotropicShift0("Anisotropic Shift 0", Range(0, 5)) = .25
		_SpecularGloss0("Specular Gloss 0", Range(8, 256)) = 64
		_SpecularStrength0("Specular Strength 0", Range(0, 1)) = .5
		[Header(Without Albedo Color)]
		_AnisotropicShift1("Anisotropic Shift 1", Range(0, 5)) = .5
		_SpecularGloss1("Specular Gloss 1", Range(8, 256)) = 16
		_SpecularStrength1("Specular Strength 1", Range(0, 1)) = .1
		[Space(10)]
		[Header(Occlusion)]
		_OcclusionColor("Occlusion Color", Color) = (0, 0, 0, 1)
		_OcclusionStrength("Occlusion Strength", Range(0, 1)) = .75
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "Queue"="AlphaTest" "UniversalMaterialType" = "Lit" }

        Pass
        {
			Name "FurryPass"
			Cull Back ZTest LEqual ZWrite On
			Tags { "LightMode" = "FurryForward" }
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
				float4 uv : TEXCOORD0;
				float4 positionWS : TEXCOORD1;
				float4 normalWS : TEXCOORD2;
				float3 tangentWS : TEXCOORD3;
			};

            sampler2D _MainTex;
			sampler2D _FurryLayerMap;
			sampler2D _AnisotropicMask;
			CBUFFER_START(UnityPerMaterial)
			half4 _ColorTint;
            float4 _MainTex_ST;
			float4 _FurryLayerMap_ST;
			half _FurryThickness;
			half _Translucent;
			half3 _SpecularColor;
			half _Fresnel;
			half _RimStrength;
			float4 _AnisotropicMask_ST;
			half _AnisotropicShift0;
			half _SpecularGloss0;
			half _SpecularStrength0;
			half _AnisotropicShift1;
			half _SpecularGloss1;
			half _SpecularStrength1;
			half3 _OcclusionColor;
			half _OcclusionStrength;
			CBUFFER_END
			float _FurryRefer;
			float _FurryOffset;
			float3 _Gravity;
			float _GravityStrength;

			inline float3 CalcFurryPositionWS(float3 positionWS, inout float3 normalWS, float2 uv)
			{
				float3 direction = normalize(lerp(normalWS, _Gravity * _GravityStrength + normalWS * (1 - _GravityStrength), _FurryRefer));
				normalWS = lerp(normalWS, direction, _FurryRefer);
				return positionWS + direction * _FurryOffset;
			}

			inline half Fresnel(float VoN)
			{
				return saturate(_Fresnel + (1 - _Fresnel) * pow(1 - VoN, 5));
			}

			inline float3 TShift(float3 tangent, float3 normal, half shift)
			{
				return normalize(tangent + shift * normal);
			}

			inline half AnisotropicSpecular(float3 T, float3 V, float3 L, half exponent)
			{
				float3 H = normalize(L + V);
				float dotTH = dot(T, H);
				float sinTH = sqrt(1 - dotTH * dotTH);
				float dirAtten = smoothstep(-1, 0, dotTH);
				return dirAtten * pow(sinTH, exponent);
			}

			float3 CalcLight(half3 albedo, Light light, float3 normalWS, float3 tangentWS0, float3 tangentWS1, float3 viewWS, float fresnel, float refer, inout float3 specCol)
			{
				half NoL = dot(normalWS, light.direction);
				half halfLambert = saturate(NoL * .5 + .5);
				half3 lightCol = light.color * light.distanceAttenuation * light.shadowAttenuation * max(0, NoL + refer);
				half3 anisotropicSpec0 = AnisotropicSpecular(tangentWS0, viewWS, light.direction, _SpecularGloss0) * refer * _Translucent * _SpecularStrength0 * albedo;
				half3 anisotropicSpec1 = AnisotropicSpecular(tangentWS1, viewWS, light.direction, _SpecularGloss1) * refer * _Translucent * _SpecularStrength1;
				half3 fresnelCol = max(0, fresnel * (NoL + refer)) * _RimStrength;
				specCol += (fresnelCol + anisotropicSpec0 + anisotropicSpec1) * light.color * _SpecularColor;
				return lightCol;
			}

            Varyings vert (Attributes input)
            {
                Varyings output;
				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
				float3 normalWS = normalInput.normalWS;
				float3 positionWS = CalcFurryPositionWS(TransformObjectToWorld(input.positionOS), normalWS, input.uv);
				output.positionWS.xyz = positionWS;
				output.normalWS.xyz = normalWS;
				output.tangentWS = normalInput.bitangentWS;
				output.positionCS = TransformWorldToHClip(positionWS);
				output.uv.xy = TRANSFORM_TEX(input.uv, _MainTex);
				output.uv.zw = input.uv * _FurryLayerMap_ST.xy + _FurryOffset * _FurryLayerMap_ST.zw;
				output.normalWS.w = input.uv.x * _AnisotropicMask_ST.x + _AnisotropicMask_ST.z;
				output.positionWS.w = ComputeFogFactor(output.positionCS.z);
				return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
				half mask = tex2D(_FurryLayerMap, input.uv.zw).r;
				half refer = pow(abs(_FurryRefer), _FurryThickness);
				clip(step(refer, mask) - .5);

				half4 col = tex2D(_MainTex, input.uv.xy) * _ColorTint;
				half occlusion = lerp(1, refer, _OcclusionStrength);
				float3 normalWS = normalize(input.normalWS.xyz);
				float3 viewWS = normalize(GetWorldSpaceViewDir(input.positionWS.xyz));
				float3 tangentWS = normalize(input.tangentWS);
				half anisotropicMask = tex2D(_AnisotropicMask, float2(input.normalWS.w, _AnisotropicMask_ST.y + _AnisotropicMask_ST.w)).r;
				half fresnel = pow(1 - saturate(dot(normalWS, viewWS)), _Fresnel);

				float3 tangentWS0 = TShift(tangentWS, normalWS, anisotropicMask - _AnisotropicShift0);
				float3 tangentWS1 = TShift(tangentWS, normalWS, anisotropicMask - _AnisotropicShift1);

				half3 indirectCol = SampleSH(normalWS);
				half3 lightCol, specCol = 0;
			#if _MAIN_LIGHT_SHADOWS
				Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS.xyz));
			#else
				Light mainLight = GetMainLight();
			#endif
				lightCol = CalcLight(col.xyz, mainLight, normalWS, tangentWS0, tangentWS1, viewWS, fresnel, refer, specCol);

			#if _ADDITIONAL_LIGHTS
				int additionalLightsCount = GetAdditionalLightsCount();
				for(int i = 0; i < additionalLightsCount; i++)
				{
					int perObjectLightIndex = GetPerObjectLightIndex(i);
					Light light = GetAdditionalPerObjectLight(perObjectLightIndex, input.positionWS.xyz);
					light.shadowAttenuation = AdditionalLightRealtimeShadow(perObjectLightIndex, input.positionWS.xyz);
					lightCol += CalcLight(col.xyz, light, normalWS, tangentWS0, tangentWS1, viewWS, fresnel, refer, specCol);
				}
			#endif
				col.xyz = col.xyz * lerp(_OcclusionColor, max(indirectCol, lightCol), occlusion) + specCol * occlusion;
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