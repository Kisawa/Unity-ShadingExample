#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"

float3 _LightDirection;
float3 _LightPosition;

TEXTURE2D_X_FLOAT(_BackDepthTexture);
SAMPLER(sampler_BackDepthTexture);

struct Attributes_Position
{
	float3 positionOS : POSITION;
};

struct Varyings_Position
{
	float4 positionCS : SV_POSITION;
};

struct Attributes_Position_Normal
{
	float3 positionOS : POSITION;
	float3 normalOS : NORMAL;
};

struct Varyings_NormalVS_Depth
{
	float4 positionCS : SV_POSITION;
	float4 normalVS_depth : TEXCOORD0;
};

inline float2 EncodeFloatRG(float v)
{
	float2 kEncodeMul = float2(1.0, 255.0);
	float kEncodeBit = 1.0/255.0;
	float2 enc = kEncodeMul * v;
	enc = frac (enc);
	enc.x -= enc.y * kEncodeBit;
	return enc;
}

inline float2 EncodeViewNormalStereo(float3 n)
{
	float kScale = 1.7777;
	float2 enc;
	enc = n.xy / (n.z+1);
	enc /= kScale;
	enc = enc*0.5+0.5;
	return enc;
}

inline float4 EncodeDepthNormal( float depth, float3 normal )
{
	float4 enc;
	enc.xy = EncodeViewNormalStereo (normal);
	enc.zw = EncodeFloatRG (depth);
	return enc;
}

inline float DecodeFloatRG(float2 enc)
{
	float2 kDecodeDot = float2(1.0, 1/255.0);
	return dot(enc, kDecodeDot);
}

inline float3 DecodeViewNormalStereo(float4 enc4)
{
	float kScale = 1.7777;
	float3 nn = enc4.xyz*float3(2*kScale,2*kScale,0) + float3(-kScale,-kScale,1);
	float g = 2.0 / dot(nn.xyz,nn.xyz);
	float3 n;
	n.xy = g*nn.xy;
	n.z = g-1;
	return n;
}

inline void DecodeDepthNormal(float4 enc, out float depth, out float3 normal)
{
	depth = DecodeFloatRG (enc.zw);
	normal = DecodeViewNormalStereo (enc);
}

inline float SampleBackDepth(float2 uv)
{
	return SAMPLE_TEXTURE2D_X(_BackDepthTexture, sampler_BackDepthTexture, UnityStereoTransformScreenSpaceTex(uv)).r;
}

Varyings_Position ShadowCasterVertex(Attributes_Position_Normal input)
{
    Varyings_Position output;
	VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);
	VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

	#if _CASTING_PUNCTUAL_LIGHT_SHADOW
		float3 lightDirectionWS = normalize(_LightPosition - vertexInput.positionWS);
	#else
		float3 lightDirectionWS = _LightDirection;
	#endif

	float4 positionCS = TransformWorldToHClip(ApplyShadowBias(vertexInput.positionWS, normalInput.normalWS, lightDirectionWS));
#if UNITY_REVERSED_Z
	positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#else
	positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#endif
	output.positionCS = positionCS;
	return output;
}

Varyings_Position DepthOnlyVertex(Attributes_Position input)
{
    Varyings_Position output;
	output.positionCS = TransformObjectToHClip(input.positionOS);
    return output;
}

void NullFragment(Varyings_Position input) { }

Varyings_NormalVS_Depth DepthViewNormalVertex(Attributes_Position_Normal input)
{
    Varyings_NormalVS_Depth output;
	VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);
	output.positionCS = vertexInput.positionCS;
	output.normalVS_depth.xyz = TransformWorldToViewDir(TransformObjectToWorldNormal(input.normalOS), true);
	output.normalVS_depth.w = -(vertexInput.positionVS.z * _ProjectionParams.w);
    return output;
}

half4 DepthViewNormalFragment(Varyings_NormalVS_Depth input) : SV_Target
{
	return EncodeDepthNormal(input.normalVS_depth.w, normalize(input.normalVS_depth.xyz));
}