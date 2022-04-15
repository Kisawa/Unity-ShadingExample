Shader "Unlit/Translucent"
{
    Properties
    {
		_ColorTint("Color Tint", Color) = (1, 1, 1, 1)
        _MainTex("Texture", 2D) = "white" {}
		_Ior("Ior", Range(0, 1)) = .97
		_Smoothness("Smoothness", Range(0, 1)) = .5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "Queue"="AlphaTest+100" "UniversalMaterialType" = "Lit" }

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
			#include "CommonPass.hlsl"

            struct Attributes
            {
                float3 positionOS : POSITION;
				float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
				float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float4 positionWS : TEXCOORD1;
				float3 normalWS : TEXCOORD2;
				float4 positionSS : TEXCOORD3;
				float3 positionVS : TEXCOORD4;
            };

			sampler2D _MainTex;
			sampler2D _CameraOpaqueTexture;
			CBUFFER_START(UnityPerMaterial)
			half4 _ColorTint;
			float4 _MainTex_ST;
			half _Ior;
			half _Smoothness;
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
				output.positionSS = ComputeScreenPos(output.positionCS);
				output.positionVS = vertexInput.positionVS;
				return output;
            }

			inline half Fresnel(float VoN)
			{
				return saturate(1 - _Ior + _Ior * pow(1 - VoN, 5));
			}

			sampler2D _BackDepthViewNormalTexture;
			float2 _UVToView;

			inline float3 CalcViewPos(float2 uv, float depth01)
			{
				float2 ndc = uv * 2.0 - 1.0;
				float3 viewDir = float3(ndc * _UVToView, 1);
				return viewDir * depth01 * _ProjectionParams.z;
			}

			#define NUM_ITER 7
			half3 CalcRefract(float2 uv, float3 positionVS, float3 refractDirVS)
			{
				float2 _uv = uv;
				float3 _positionVS = positionVS;
				[unroll]
				for(int i = 0; i < NUM_ITER; i++)
				{
					float backDepth01;
					float3 backNormalVS;
					DecodeDepthNormal(tex2D(_BackDepthViewNormalTexture, _uv), backDepth01, backNormalVS);
					float3 backPositionVS =  CalcViewPos(_uv, backDepth01);
					float disFromFrontToBack = length(backPositionVS - _positionVS);
					float3 nextPositionVS = _positionVS + refractDirVS * disFromFrontToBack;
					float4 nextPositionSS = ComputeScreenPos(TransformWViewToHClip(nextPositionVS));
					_uv = nextPositionSS.xy / nextPositionSS.w;
					_positionVS = nextPositionVS;
				}
				float3 _viewVS = normalize(_positionVS);
				float3 _backNormalVS = DecodeViewNormalStereo(tex2D(_BackDepthViewNormalTexture, _uv));
				half fresnel = Fresnel(dot(_viewVS, _backNormalVS));
				float3 reflectDirVS = reflect(-_viewVS, _backNormalVS);
				half4 reflectEnvironment = SAMPLE_TEXTURECUBE(unity_SpecCube0, samplerunity_SpecCube0, reflectDirVS);
				half3 reflectCol = DecodeHDREnvironment(reflectEnvironment, unity_SpecCube0_HDR) * fresnel;
				half3 refractCol = tex2D(_CameraOpaqueTexture, _uv).xyz * (1 - fresnel);
				return reflectCol + refractCol;
			}

            half4 frag (Varyings input) : SV_Target
            {
                half4 col = tex2D(_MainTex, input.uv) * _ColorTint;
				half3 normalWS = normalize(input.normalWS);
				half3 viewWS = normalize(GetWorldSpaceViewDir(input.positionWS.xyz));
				float2 positionSS = input.positionSS.xy / input.positionSS.w;

				half fresnel = Fresnel(dot(viewWS, normalWS));
				//Reflection
				float3 reflectDirWS = reflect(-viewWS, normalWS);
				half4 reflectEnvironment = SAMPLE_TEXTURECUBE(unity_SpecCube0, samplerunity_SpecCube0, reflectDirWS);
				half3 reflectCol = DecodeHDREnvironment(reflectEnvironment, unity_SpecCube0_HDR) * fresnel;
				//Refraction
				float3 refractDirWS = refract(-viewWS, normalWS, _Ior);
				half3 refractCol = CalcRefract(positionSS, input.positionVS, TransformWorldToViewDir(refractDirWS, true)) * (1 - fresnel);
				//Blend
				col.xyz = lerp(col.xyz, reflectCol + refractCol, _Smoothness);

				half3 indirectCol = SampleSH(normalWS);
			#if _MAIN_LIGHT_SHADOWS
				Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS.xyz));
			#else
				Light mainLight = GetMainLight();
			#endif
				half halfLambert = saturate(dot(normalWS, mainLight.direction) * .5 + .5);
				half3 mainLightCol = mainLight.color * mainLight.distanceAttenuation * mainLight.shadowAttenuation * halfLambert;
				col.xyz *= max(indirectCol, mainLightCol);
				
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

		Pass
		{
			Name "BackDepth"
			Tags { "LightMode"= "BackDepth" }
			ZWrite On ZTest LEqual ColorMask 0 Cull Front
			HLSLPROGRAM
			#include "CommonPass.hlsl"
            #pragma vertex DepthOnlyVertex
            #pragma fragment NullFragment
            ENDHLSL
		}

		Pass
		{
			Name "DepthViewNormal"
			Tags { "LightMode"= "DepthViewNormal" }
			ZWrite On ZTest LEqual Cull [_DpethViewNormalCull]
			HLSLPROGRAM
			#include "CommonPass.hlsl"
			#pragma vertex DepthViewNormalVertex
            #pragma fragment DepthViewNormalFragment
			ENDHLSL
		}
    }
}