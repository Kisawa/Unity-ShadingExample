Shader "Unlit/Toon"
{
    Properties
    {
		[Header(Outline)]
		[Toggle(_UseTangentData)]_UseTangentData("Use Tangent Data", Float) = 0
		_OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
		_OutlineWidth("Outline Width", Range(0, .1)) = .01
		[Space(10)]
		[Header(Surface)]
		_Color("Base Color", Color) = (1, 1, 1, 1)
        _MainTex("Main Tex", 2D) = "white"{}
		[Space(5)]
		[Toggle(_IsFace)]_IsFace("Is Face", Float) = 0
		_FaceSDF("Face SDF", 2D) = "black"{}
		[Space(10)]
		[Header(Lighting)]
		[HDR]_SpecularColor("Specular Color", Color) = (1, 1, 1, 1)
		_RimWidth("Rim Width", Range(0, .01)) = .005
		_RimThreshold("Rim Threshold", Range(0, .1)) = .05
		[Space(5)]
		[Toggle(_AnisotropicSpecular)]_AnisotropicSpecular("Anisotropic Specular", Float) = 0
		_AnisotropicCombMap("Anisotropic Comb Map", 2D) = "black" {}
		_AnisotropicThreshold("Anisotropic Threshold", Range(0, 1)) = .5
		_AnisotropicOffset("Anisotropic Offset", Range(-1, 1)) = -0.2
		_SpecularGloss("Specular Gloss", Range(8, 256)) = 64
		[Space(5)]
		_ShadeStep("Shade Step", Range(-1, 1)) = 0
		_ShadeSmooth("Shade Smooth", Range(0, 1)) = .01
		_ShadeStrength("Shade Strength", Range(0, 1)) = .75
		[Space(10)]
		[Header(Shadow)]
		_ShadowColor("Shadow Color", Color) = (0, 0, 0)
		_ReceiveShadowMappingOffset("Receive Shadow Mapping Offset", Range(0, 1)) = 0
		[Space(10)]
		[Header(Others)]
		[Toggle(_UseClip)]_UseClip("Use Clip", Float) = 0
		_Cutoff("Cutoff", Range(0, 1)) = 0
		[HideInInspector]_PerspectiveCorrectUsage("Perspective Correct Usage", Range(0, 1)) = 0
		[HideInInspector]_BoundCenterPosWS("Bound Center PositionWS", Vector) = (0, 0, 0, 1)
    }

    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline" "Queue"="AlphaTest" "UniversalMaterialType" = "Lit" }

		HLSLINCLUDE
		#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
		#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
		#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
        #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
		#pragma multi_compile_fragment _ _SHADOWS_SOFT
		#pragma multi_compile_fog
		#pragma shader_feature_local_vertex _UseTangentData
		#pragma shader_feature_local_fragment _IsFace
		#pragma shader_feature_local_fragment _AnisotropicSpecular
		#pragma shader_feature_local_fragment _UseClip
		#include "CommonPass.hlsl"

		CBUFFER_START(UnityPerMaterial)
		half4 _OutlineColor;
		half _OutlineWidth;
		half4 _Color;
		float4 _MainTex_ST;
		half4 _SpecularColor;
		half _RimWidth;
		half _RimThreshold;
		float4 _AnisotropicCombMap_ST;
		half _AnisotropicThreshold;
		half _AnisotropicOffset;
		half _SpecularGloss;
		half _ShadeStep;
		half _ShadeSmooth;
		half _ShadeStrength;
		half3 _ShadowColor;
		float _ReceiveShadowMappingOffset;
		half _Cutoff;
		half _PerspectiveCorrectUsage;
		float3 _BoundCenterPosWS;
		CBUFFER_END
		sampler2D _MainTex;
		sampler2D _FaceSDF;
		sampler2D _AnisotropicCombMap;

		void DoClipTest(float2 positionSS)
		{
		#if _UseClip
			float2 screenPos = positionSS * _ScreenParams.xy;
			const float DITHER_THRESHOLDS[16] =
			{
				1.0 / 17.0,  9.0 / 17.0,  3.0 / 17.0, 11.0 / 17.0,
				13.0 / 17.0,  5.0 / 17.0, 15.0 / 17.0,  7.0 / 17.0,
				4.0 / 17.0, 12.0 / 17.0,  2.0 / 17.0, 10.0 / 17.0,
				16.0 / 17.0,  8.0 / 17.0, 14.0 / 17.0,  6.0 / 17.0
			};
			uint index = (uint(screenPos.x) % 4) * 4 + uint(screenPos.y) % 4;
			clip(DITHER_THRESHOLDS[index] - _Cutoff);
		#endif
		}

		float4 PerspectiveCorrect(float4 positionCS)
		{
			float centerPosVS_z = TransformWorldToView(_BoundCenterPosWS).z;
			float2 newPosCS_xy = positionCS.xy;
			newPosCS_xy *= abs(positionCS.w);
			newPosCS_xy *= rcp(abs(centerPosVS_z));
			positionCS.xy = lerp(positionCS.xy, newPosCS_xy, _PerspectiveCorrectUsage);
			return positionCS;
		}

		float4 TransformObjectToOutlineHClip(float3 positionOS, float3 normalOS, float4 tangentOS)
		{
			VertexPositionInputs vertexInput = GetVertexPositionInputs(positionOS);
		#if _UseTangentData
			VertexNormalInputs normalInput = GetVertexNormalInputs(tangentOS.xyz);
			normalInput.normalWS *= tangentOS.w;
		#else
			VertexNormalInputs normalInput = GetVertexNormalInputs(normalOS);
		#endif
			float3 positionWS = vertexInput.positionWS + normalInput.normalWS * _OutlineWidth;
			return PerspectiveCorrect(TransformWorldToHClip(positionWS));
		}

		half3 CalcRim(Light light, float3 normalWS, float2 positionSS, float depth)
		{
			float2 normalVS = TransformWorldToViewDir(normalWS, true).xy;
			half NoL = saturate(dot(light.direction, normalWS));
			positionSS = positionSS + normalVS * _RimWidth * NoL;
			float _depth = LinearEyeDepth(SampleSceneDepth(positionSS), _ZBufferParams);
			half3 rim = step(_RimThreshold, _depth - depth) * _SpecularColor.xyz * light.color * light.distanceAttenuation;
			return rim;
		}

		half3 CalcAnisotropic(float3 normalWS, float3 viewWS, half shift)
		{
			half3 lightWS = float3(0, 1, 0);
			half adjust = dot(viewWS, lightWS) + _AnisotropicThreshold;
			viewWS = normalize(lerp(lightWS, viewWS, adjust));
			float3 halfWS = normalize(lightWS + viewWS);
			float NoH = dot(normalWS, halfWS);
			float spce = max(0, sin((NoH + _AnisotropicOffset + shift) * 3.1415));
			return pow(spce, _SpecularGloss) * _SpecularColor.xyz;
		}

		half3 CalcFaceSDF(Light light, float2 uv)
		{
			half4 refer0 = tex2D(_FaceSDF, uv);
			half4 refer1 = tex2D(_FaceSDF, float2(1 - uv.x, uv.y));
			float2 right = normalize(TransformObjectToWorldDir(float3(1, 0, 0)).xz);
			float2 front = normalize(TransformObjectToWorldDir(float3(0, 0, 1)).xz);
			float2 lightDir = normalize(light.direction.xz);
			half val = dot(front, lightDir) * .5 + .5;
			half shade = (dot(right, lightDir) > 0 ? refer0.r : refer1.r) + _ShadeStep;
			shade = smoothstep(shade - _ShadeSmooth, shade + _ShadeSmooth, val);
			shade = lerp(1, shade, _ShadeStrength);
			half3 shadeCol = lerp(_ShadowColor, 1, shade);
			return light.color * shadeCol * light.distanceAttenuation;
		}

	#if _AnisotropicSpecular
		half3 CalcMainLight(Light light, float3 normalWS, inout half3 anisotropicWeight)
	#else
		half3 CalcMainLight(Light light, float3 normalWS)
	#endif
		{
			half NoL = dot(normalWS, light.direction);
			half shade = smoothstep(_ShadeStep - _ShadeSmooth, _ShadeStep + _ShadeSmooth, NoL) * light.shadowAttenuation;
			shade = lerp(1, shade, _ShadeStrength);
			half3 shadeCol = lerp(_ShadowColor, 1, shade);
			half3 col = light.color * light.distanceAttenuation * shadeCol;
		#if _AnisotropicSpecular
			anisotropicWeight += light.color * light.distanceAttenuation * saturate(NoL);
		#endif
			return col;
		}

	#if _AnisotropicSpecular
		half3 CalcAdditionalLight(Light light, float3 normalWS, inout half3 anisotropicWeight)
	#else
		half3 CalcAdditionalLight(Light light, float3 normalWS)
	#endif
		{
			half NoL = dot(normalWS, light.direction);
			half halfLambert = NoL * 0.5 + 0.5;
			half3 col = light.color * light.distanceAttenuation * light.shadowAttenuation * halfLambert;
		#if _AnisotropicSpecular
			anisotropicWeight += light.color * light.distanceAttenuation * saturate(NoL);
		#endif
			return col;
		}
		ENDHLSL

        Pass
        {
			Name "ForwardLit"
			Tags { "LightMode" = "UniversalForward" }
			Cull Back ZTest LEqual ZWrite On Blend One Zero
			Stencil
			{
				Ref 27
				Pass Replace
			}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
			{
				float3 positionOS : POSITION;
				half3 normalOS : NORMAL;
				half4 tangentOS : TANGENT;
				float2 uv : TEXCOORD0;
				half4 color : COLOR;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float4 uv : TEXCOORD0;
				half4 color : TEXCOORD1;
				float4 positionWS : TEXCOORD2;
				float4 normalWS : TEXCOORD3;
				float4 positionSS : TEXCOORD4;
			};

            Varyings vert (Attributes input)
            {
                Varyings output;
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);
				VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
				output.positionCS = PerspectiveCorrect(vertexInput.positionCS);
				float fogFactor = ComputeFogFactor(output.positionCS.z);
				output.uv.xy = TRANSFORM_TEX(input.uv, _MainTex);
				output.uv.zw = TRANSFORM_TEX(float2(input.uv.x, 1), _AnisotropicCombMap);
				output.positionSS = ComputeScreenPos(output.positionCS);
				output.positionWS = float4(vertexInput.positionWS, -vertexInput.positionVS.z);
				output.normalWS = float4(normalInput.normalWS, fogFactor);
				output.color = input.color;
				return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
				float2 positionSS = input.positionSS.xy / input.positionSS.w;
				DoClipTest(positionSS);
                half4 col = tex2D(_MainTex, input.uv.xy) * _Color;
				float3 normalWS = normalize(input.normalWS.xyz);
				float3 viewWS = normalize(GetWorldSpaceViewDir(input.positionWS.xyz));
				
				half3 indirectCol = SampleSH(0);
				half3 lightCol = 0, specCol = 0;

			#if _AnisotropicSpecular
				half shift = tex2D(_AnisotropicCombMap, input.uv.zw).x * .5;
				half3 anisotropicCol = CalcAnisotropic(normalWS, viewWS, shift), anisotropicWeight = 0;
			#endif

				Light mainLight = GetMainLight();
			#if _MAIN_LIGHT_SHADOWS
				float3 shadowTestPosWS = input.positionWS.xyz + mainLight.direction * _ReceiveShadowMappingOffset;
				float4 shadowCoord = TransformWorldToShadowCoord(shadowTestPosWS);
				mainLight.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
			#endif

			#if _IsFace
				lightCol += CalcFaceSDF(mainLight, input.uv.xy);
			#else
			#if _AnisotropicSpecular
				lightCol += CalcMainLight(mainLight, normalWS, anisotropicWeight);
			#else
				lightCol += CalcMainLight(mainLight, normalWS);
			#endif
			#endif
				specCol += CalcRim(mainLight, normalWS, positionSS, input.positionWS.w);

			#if _ADDITIONAL_LIGHTS
				int additionalLightsCount = GetAdditionalLightsCount();
				for(int i = 0; i < additionalLightsCount; i++)
				{
					int perObjectLightIndex = GetPerObjectLightIndex(i);
					Light light = GetAdditionalPerObjectLight(perObjectLightIndex, input.positionWS.xyz);
					light.shadowAttenuation = AdditionalLightRealtimeShadow(perObjectLightIndex, input.positionWS.xyz);
				#if _AnisotropicSpecular
					lightCol += CalcAdditionalLight(light, normalWS, anisotropicWeight);
				#else
					lightCol += CalcAdditionalLight(light, normalWS);
				#endif
					specCol += CalcRim(light, normalWS, positionSS, input.positionWS.w);
				}
			#endif

			#if _AnisotropicSpecular
				specCol += anisotropicCol * anisotropicWeight;
			#endif
				col.xyz = col.xyz * max(indirectCol, lightCol) + specCol;
				col.xyz = MixFog(col.xyz, input.normalWS.w);
                return col;
            }
            ENDHLSL
        }
		
		Pass
        {
			Name "Outline"
			Tags { "LightMode" = "Outline" }
			Cull Front
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
			{
				float3 positionOS : POSITION;
				float3 normalOS : NORMAL;
				float4 tangentOS : TANGENT;
				half4 color : COLOR;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				half4 color : TEXCOORD0;
				float4 positionSS : TEXCOORD1;
			};

            Varyings vert(Attributes input)
            {
                Varyings output;
				output.positionCS = TransformObjectToOutlineHClip(input.positionOS, input.normalOS, input.tangentOS);
				output.positionSS = ComputeScreenPos(output.positionCS);
				output.color = input.color;
                return output;
            }

            half4 frag (Varyings input) : SV_Target
            {
				DoClipTest(input.positionSS.xy / input.positionSS.w);
                return _OutlineColor;
            }
            ENDHLSL
        }

		Pass
		{
			Name "ShadowCaster"
			Tags { "LightMode"="ShadowCaster" }
			ZWrite On ZTest LEqual ColorMask 0 Cull Back
			HLSLPROGRAM
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
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
			{
				float3 positionOS : POSITION;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float4 positionSS : TEXCOORD1;
			};

            Varyings vert(Attributes input)
            {
                Varyings output;
				output.positionCS = PerspectiveCorrect(TransformObjectToHClip(input.positionOS));
				output.positionSS = ComputeScreenPos(output.positionCS);
                return output;
            }

            void frag (Varyings input)
			{
				DoClipTest(input.positionSS.xy / input.positionSS.w);
			}
            ENDHLSL
		}

		/*
		Pass
		{
			Name "BackDepth"
			Tags { "LightMode"= "BackDepth" }
			ZWrite On ZTest LEqual ColorMask 0 Cull Front
			HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
			{
				float3 positionOS : POSITION;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float4 positionSS : TEXCOORD0;
			};

            Varyings vert(Attributes input)
            {
                Varyings output;
				output.positionCS = PerspectiveCorrect(TransformObjectToHClip(input.positionOS));
				output.positionSS = ComputeScreenPos(output.positionCS);
                return output;
            }

            void frag (Varyings input)
			{
				DoClipTest(input.positionSS.xy / input.positionSS.w);
			}
            ENDHLSL
		}

		Pass
		{
			Name "DepthViewNormal"
			Tags { "LightMode"= "DepthViewNormal" }
			ZWrite On ZTest LEqual Cull [_DpethViewNormalCull]
			HLSLPROGRAM
			#pragma vertex vert
            #pragma fragment frag

			struct Attributes
			{
				float3 positionOS : POSITION;
				float3 normalOS : NORMAL;
			};

			struct Varyings
			{
				float4 positionCS : SV_POSITION;
				float4 normalVS_depth : TEXCOORD0;
				float4 positionSS : TEXCOORD1;
			};

			Varyings vert(Attributes input)
			{
				Varyings output;
				VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);
				output.positionCS = PerspectiveCorrect(vertexInput.positionCS);
				output.normalVS_depth.xyz = TransformWorldToViewDir(TransformObjectToWorldNormal(input.normalOS));
				output.normalVS_depth.w = -(vertexInput.positionVS.z * _ProjectionParams.w);
				output.positionSS = ComputeScreenPos(output.positionCS);
				return output;
			}

			half4 frag(Varyings input) : SV_Target
			{
				DoClipTest(input.positionSS.xy / input.positionSS.w);
				return EncodeDepthNormal(input.normalVS_depth.w, normalize(input.normalVS_depth.xyz));
			}
			ENDHLSL
		}
		*/
    }
}
