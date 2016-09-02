// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/Raymarch"
{
	Properties
	{
		_Radius("Radius", float) = 1
		_Centre("Centre", vector) = (0,0,0)
		_Color("Color", Color) = (1,1,1,1)
		_ColorEmpty("Color Empty", Color) = (0,0,0,0)
	}
		SubShader
	{
		//Tags{ "RenderType" = "Transparent" }
		//LOD 100

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

#define STEPS 64
#define STEP_SIZE 0.005
#define MIN_DISTANCE 0.0001

	float3 _Centre;
	float _Radius;

		struct v2f
	{
		float4 pos : SV_POSITION;	// Clip space
		float3 wPos : TEXCOORD1;	// World position
	};

	v2f vert(appdata_full v)
	{
		v2f o;
		o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
		o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
		return o;
	}
	
	/*
	float vmax(float3 v)
	{
		return max(max(v.x, v.y), v.z);
	}*/

	float sdf_boxcheap(float3 p, float3 c, float3 s)
	{
		return vmax(abs(p - c) - s);
	}

	float sphere(float3 p, float3 c, float3 r)
	{
		return distance(p, c) - r;
	}

	float map(float3 p)
	{

		float sphere1 = sphere(p, float3(0, 0, 0), 1);
		float sphere2 = sphere(p, float3(0, 0, -0.5 + -1.5* (_SinTime.x - 0.3)), 0.2 * _SinTime.y);
		float sphere3 = sphere(p, float3(0, 0, -0.5 + -1.6*_SinTime.x), 0.1);

		return fOpUnionRound(fOpIntersectionColumns(sphere1, -sphere2, 0.4, 3), sphere3, 0.2);
	}


	float mapButtocks(float3 p)
	{
		float sphere1 = sphere(p, float3(-0.5, 0, 0), 1);
		float sphere2 = sphere(p, float3(0.5, 0, 0), 1);

		float sphere3 = sphere(p, float3(-0.5, -1, 0), 0.8);
		float sphere4 = sphere(p, float3(0.5, -1, 0), 0.8);

		float sphere5 = sphere(p, float3(0, 1, 0.3), 1.3);

		float box1 = fBox(p + float3(0, 1, 0), _Centre);
		float box2 = fBox(p + float3(0, 0, 0), _Centre);
		float box3 = fBox(p + float3(0, -1, 0), _Centre);

		return fOpUnionColumns(fOpUnionRound(fOpUnionRound(fOpUnionColumns(sphere1, sphere2, 0.1, 2), sphere3, 0.05), sphere4, 0.1), sphere5, 0.15, 2);

		/*
		return min(max(sphere(p, float3(-0.5, 0, 0), 1),
			sphere(p, float3(0.5, 0, 0), 1)),
			sdf_boxcheap(p, float3(0, 0, 0), fixed3(1,0.2,0.2)) );
			*/
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
		fixed NdotL = max(dot(normal, lightDir), 0);
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

	fixed4 renderSurface(float3 p)
	{
		float3 n = normal(p);
		return simpleLambert(n) + lambertLight(n, fixed3(0,-1,1), fixed3(1,0,1)) + fresnelLight(n, fixed3(0.3,1,0.3), 2);
	}

	bool sphereHit(float3 p)
	{
		return distance(p,_Centre) < _Radius;
	}

	float sphereDistance(float3 p)
	{
		return distance(p, _Centre) - _Radius;
	}



	fixed4 raymarch(float3 position, float3 direction)
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

	bool raymarchHit(float3 position, float3 direction)
	{
		for (int i = 0; i < STEPS; i++)
		{
			if (sphereHit(position))
				return true;

			position += direction * STEP_SIZE;
		}

		return false;
	}






	fixed4 frag(v2f i) : SV_Target
	{
		float3 worldPosition = i.wPos;
		float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);

		//return lerp(fixed4(0, 0, 0, 0), fixed4(2, 2, 2, 2), raymarch(worldPosition, viewDirection));
		
		return lerp(_ColorEmpty, _Color, raymarch(worldPosition, viewDirection));


		//return renderSurface(raymarch(worldPosition, viewDirection));

		/*
		if (raymarchHit(worldPosition, viewDirection))
			return fixed4(1,0,0,1); // Red if hit the ball
		else
			return fixed4(1,1,1,1); // White otherwise*/
	}


		ENDCG
	}
	}
}
