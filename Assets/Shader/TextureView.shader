Shader "PostProcessing/TextureView"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma multi_compile _ _DEPTHTEXTURE _DEPTHNORMALTEXTURE
            #include "CommonPass.hlsl"

            struct Attributes
            {
                float3 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            Varyings vert (Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS);
                output.uv = input.uv;
                return output;
            }

		#if _DEPTHTEXTURE
			TEXTURE2D_X_FLOAT(_MainTex);
			SAMPLER(sampler_MainTex);

			float SampleDepth(float2 uv)
			{
				return SAMPLE_TEXTURE2D_X(_MainTex, sampler_MainTex, UnityStereoTransformScreenSpaceTex(uv)).r;
			}
		#else
			sampler2D _MainTex;
		#endif
			
            half4 frag (Varyings input) : SV_Target
            {
			#if _DEPTHTEXTURE
                half4 col = Linear01Depth(SampleDepth(input.uv), _ZBufferParams);
			#elif _DEPTHNORMALTEXTURE
				float depth;
				float3 normalVS;
				DecodeDepthNormal(tex2D(_MainTex, input.uv), depth, normalVS);
				half4 col = half4(normalVS * .5 + .5, 1);
			#else
				half4 col = tex2D(_MainTex, input.uv);
			#endif
                return col;
            }
            ENDHLSL
        }
    }
}