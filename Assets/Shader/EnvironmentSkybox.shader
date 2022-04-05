Shader "Environment/Skybox"
{
	Properties
	{
		_TopColor("Top Color", Color) = (.07, .4, .3)
		_BottomColor("Bottom Color", Color) = (.006, .048, .057)
		_Step("Step", Range(0, 1)) = .5
		_Smooth("Smooth", Range(0, 1)) = 1
		_Crimp("Crimp", Range(0, 1)) = .3
		_Angle("Angle", Range(-3.14, 3.14)) = 0
	}
    SubShader
    {
        Tags { "RenderType"="Background" "Queue"="Background" }

        Pass
        {
			ZWrite Off Cull Off
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
				float4 positionSS : TEXCOORD1;
            };

			fixed4 _TopColor;
			fixed4 _BottomColor;
			half _Step;
			half _Smooth;
			half _Crimp;
			half _Angle;

			fixed4 CalcBackground(float2 texcoord)
			{
				texcoord.y = pow(texcoord.y, pow(sin(texcoord.x * 1.57 + 0.785), _Crimp));

				float cos_angle = cos(_Angle);
				float sin_angle = sin(_Angle);
				texcoord = float2(texcoord.x * cos_angle - texcoord.y * sin_angle, texcoord.x * sin_angle + texcoord.y * cos_angle);

				fixed4 col = lerp(_TopColor, _BottomColor, saturate(smoothstep(_Step - _Smooth * .5, _Step + _Smooth * .5, 1 - texcoord.y)));
				return col;
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.positionSS = ComputeScreenPos(o.vertex);
				o.uv = v.uv;
				return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				float2 positionSS = i.positionSS.xy / i.positionSS.w;
				fixed4 col = CalcBackground(positionSS);
				return col;
            }
            ENDCG
        }
    }
}
