// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "RaymarchNoise"
{
	Properties
	{
		_MainTex("Main Tex", 2D) = "white" {}
		_RampTex("Ramp", 2D) = "white" {}
		_Radius("Radius", float) = 1
		_Centre("Centre", vector) = (0,0,0)
		_Color("Color", Color) = (1,1,1,1)
		_ColorEmpty("Color Empty", Color) = (0,0,0,0)
		_FresnelColor("Fresnel Color", Color) = (1,0,0,0)
		_FresnelPower("Fresnel Power", float) = 2
		_Light2Color("Light 2 Color", Color) = (1,1,1,1)
		_Light2Dir("Light 2 Direction", Vector) = (0,1,0,0)
		_FogColor1("Color Fog 1", Color) = (1,1,1,1)
		_FogColor2("Color Fog 2", Color) = (1,1,0,1)
		_FogDensity("Fog Density", float) = 0.01
		_Move("Move", float) = 0
		_X("X", float) = 0
		_Y("Y", float) = 0
	}
		SubShader
	{
		Tags{ "RenderType" = "Transparent" "Queue" = "Transparent" }
		//LOD 100

			Blend SrcAlpha OneMinusSrcAlpha


		Pass
	{
		CGPROGRAM

#pragma vertex vert
#pragma fragment frag
		// make fog work
		//#pragma multi_compile_fog
#include "Lighting.cginc"
#include "UnityCG.cginc"
#include "hg_sdf.cginc"
#include "noise.cginc"

#define STEPS 32
#define FOGSTEPS 1024
#define STEP_SIZE 0.005
#define MIN_DISTANCE 0.1 // 0.0001

	float3 _Centre;
	float _Radius;

	float _FogDensity;

	sampler2D _RampTex;
	sampler2D _MainTex;

	float4 _MainTex_ST;

	struct v2f
	{
		float4 pos : SV_POSITION;	// Clip space
		float2 uv : TEXCOORD0;
		float3 wPos : TEXCOORD1;	// World position

		float4 color : COLOR;
	};

	v2f vert(appdata_full v)
	{
		v2f o;
		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
		o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;

		o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);

		o.color = v.color;

		return o;
	}

	float sdf_boxcheap(float3 p, float3 c, float3 s)
	{
		return vmax(abs(p - c) - s);
	}

	float sphere(float3 p, float3 c, float3 r)
	{
		return distance(p, c) - r;
	}

	float nSphere(float3 p, float3 r, float depth)
	{
		return length(p) - (r +  noiseIQ(p * depth));
	}

	float iSphere(float3 p, float3 r)
	{
		return -length(p) - r;
	}

	// ----
	// MAPS
	// ----

	fixed _Move;
	fixed _X;
	fixed _Y;
 
	float map(float3 p)
	{
		return _X + noiseIQ(_Y * p + fixed3(_Time.z * 5, 0, 0));
	}


	float3 normal(float3 p)
	{
		const float eps = 0.01;

		return normalize
		(float3
			(map(p + float3(eps, 0, 0)) - map(p - float3(eps, 0, 0)),
				map(p + float3(0, eps, 0)) - map(p - float3(0, eps, 0)),
				map(p + float3(0, 0, eps)) - map(p - float3(0, 0, eps))
				)
		);
	}

	fixed4 _Color;
	fixed4 _ColorEmpty;

	fixed4 _Light2Color;
	fixed4 _Light2Dir;

	fixed4 simpleLambert(fixed3 normal) {
		fixed3 lightDir = _WorldSpaceLightPos0.xyz;	// Light direction
		fixed3 lightCol = _LightColor0.rgb;		// Light color

		fixed NdotL = max(dot(normal, lightDir), 0);
		fixed4 c;
		c.rgb = _Color * lightCol * NdotL;
		c.a = 1;
		return c;
	}

	fixed4 lambertLight(fixed3 normal, fixed3 lightDir, fixed3 lightCol)
	{
		fixed NdotL = max(dot(normal, -lightDir), 0);
		fixed4 c;
		c.rgb = _Color * lightCol * NdotL;
		c.a = 1;
		return c;
	}

	fixed4 fresnelLight(fixed3 normal, fixed3 color, fixed rimPower)
	{
		float3 viewDirection = UNITY_MATRIX_IT_MV[2].xyz;

		fixed rim = saturate(dot(normalize(viewDirection), normal));
		rim = pow(rim, rimPower);

		fixed4 c;
		c.rgb = color * rim;
		c.a = 1;

		return c;
	}

	fixed3 _FresnelColor;
	fixed _FresnelPower;

	fixed4 _FogColor1;
	fixed4 _FogColor2;

	fixed4 renderSurface(float3 p)
	{
		float3 n = normal(p);
		return /*simpleLambert(n) +*/ lambertLight(n, _Light2Dir, _Light2Color) + fresnelLight(n, _FresnelColor, _FresnelPower);
	}


	fixed4 renderDepth(float p, float depth)
	{
		float d = depth * _FogDensity;

		fixed4 c;

		// COLOR LERP RENDERING
		c.rgb = lerp(_FogColor1, _FogColor2, d);

		// RAMP RENDERING
		//c.rgb = tex2D(_RampTex, float2(d, 0.5)).rgb;

		c.a = d;

		//float3 n = normal(p);

		return c;
	}



	// --------
	// RAYMARCH
	// --------

	fixed4 raymarchOriginal(float3 position, float3 direction)
	{
		for (int i = 0; i < STEPS; i++)
		{
			float distance = map(position);

			if (distance < MIN_DISTANCE)
				return renderSurface(position);

			position += distance * direction;
		}
		return fixed4(0, 0, 0, 0);
	}

	fixed4 raymarchDensity(float3 position, float3 direction)
	{
		float depth = 0;

		for (int i = 0; i < FOGSTEPS; i++)
		{
			float distance = map(position);

			if (distance < MIN_DISTANCE)
				depth += - distance * 3;

			position += direction * STEP_SIZE * 10;// *i * 0.05;
		}

		if (depth == 0)
			return fixed4(0, 0, 0, 0);

		return renderDepth(position, depth);
	}


	fixed4 frag(v2f i) : SV_Target
	{
		float3 worldPosition = i.wPos;
		float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);

		fixed4 raymarched = raymarchOriginal(i.wPos, viewDirection);

		fixed4 c;
		c.rgb = tex2D(_MainTex, i.uv).rgb * 2 + raymarched.rgb;
		c.a = i.color.a * tex2D(_MainTex, i.uv).a * raymarched.a * 3;


		//return raymarched;
		return c;


	}


		ENDCG
	}
	}
}
