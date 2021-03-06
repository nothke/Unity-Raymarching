﻿// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/Raymarch"
{
	Properties
	{
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

		Blend One One


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

#define STEPS 64
#define FOGSTEPS 1024
#define STEP_SIZE 0.005
#define MIN_DISTANCE 0.1 // 0.0001

	float3 _Centre;
	float _Radius;

	float _FogDensity;

	sampler2D _RampTex;

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

		//float sphere1 = sphere(p, float3(0, 0, 0), 1);
		//float sphere1 = sphere(noiseIQ(p), float3(0, 0, 0), 1);

		float noiseSphere = max(noiseIQ(p * 10), -sphere(p, float3(0, 0, 0), 1));

		float sphere2 = sphere(p, float3(0, 0, -0.5 + -1.5* (_SinTime.x - 0.3)), 0.2 * _SinTime.y);
		float sphere3 = sphere(p, float3(0, 0, -0.5 + -1.6*_SinTime.x), 0.1);

		float boundsSphere = sphere(p, float3(0, 0, 0), 100);
		float fillSphere = sphere(p, float3(0, 0, 0), 98);

		return nSphere(p, 10, 6);

		//return min(max(sphere(-noiseIQ(p * 10), float3(0,0,0), 1 * p * _SinTime.x), boundsSphere), fillSphere);
	
		//return fSphere(p, 10);
	}

	float mapFog(float3 p)
	{
		return sphere(p, float3(0, 0, 0), 11);
	}

	float mapSimpleShock(float3 p)
	{
		

		//float cone = fCone(p, 1, 1) * 10;
		float sphere = fSphere(float3(0, _Move, 0) + p, _Y) * 0.1;

		//return max(cone, sphere) * _X;

		float peak = length(p.xz) - p.y;
		float nPeak = length(p.xz) - p.y * 0.1;

		float fade = _X + p.y * p.y * 0.3;

		return peak + nPeak;

		//return lerp(-fade, max(peak, sphere), 0.99);
	}


	float mapShockRot(float3 p)
	{
		//pmodPolar(p.xy, 8);

		float sRadius1 = _Move + sin(p.y * 1);
		float sRadius2 = 1 + sin(0.5 + p.y * 0.5);

		float fade = -p.y * 0.01;

		float interval = 0.5  ;

		float fRad = length(p.xz) - 0.7 * (3 + sin(p.y * interval));
		float fLin = sin(1 + p.y * 0.25) * 0.5;

		float f = length(float2(fRad, fLin)) - 0.4;

		float gRad = length(p.xz) - 1 * sin(3 + p.y * 0.5);
		float gLin = sin(0.6 + p.y * 0.4) * 0.2;

		float g = length(float2(gRad, gLin)) - 1;

		//pmod1(p.x, 1);

		//float sphere = length(p) - 1;

		//f = min(f, g);

		//pmod1(p.y, 12);

		float sc = fCone(float3(0, 5, 0) + p, 2.2, 5.5) *  100*(4 + noiseIQ(_SinTime.z * 1000));

		//good:
		//f = max(lerp(f, blur, _X), -blur * 0.2 - _Y);

		f = min(f * 1.12, sc);

		f = max(lerp(f, fade, 0.5), -fade * 0.2 - 0.18);

		f = fSphere(p, 1);

		fixed f2 = fixed3(0.4,0,0) + fSphere(p, 2);

		f = fOpUnionRound(f, f2, 0.1);

		//if (f < 0) f = - f - 0.15;
		//if (g < 0) g = -g -0.15;

		//return sphere;
		return f * 1;
		//return  lerp(min(f , g), max(f,g), 0.1) * 20 ;
	}

	float mapShock(float3 p)
	{
		

		float f = length(float2(length(p.xz) - (1.4 + sin(p.y * 1)), sin(0.6 + p.y * 0.5) * 0.4)) - 0.8;
		float g = max(sin(p.y), f);

		return f * 2 + g * 0.3;
	}

	float mapExhaust(float3 p)
	{
		float fade = p.x * 0.02;

		//float lnt = length(float3(sin(p.x *1.1) * fade, p.y, p.z * fade));

		//float lnt = length(p);

		//float fog1 = length(p) - 5;
		//float fog2 = length(float3(sin(p.x), p.y, p.z)) - 1.1;
		//float fogInv = length(p) - 1;

		//float fog2 = length(float3)

		

		//float d = 0;

		fixed nosie = lerp(0.99, 1.01, noiseIQ(_SinTime.z * 100) * 9);

		fixed offsetNoise =  (-0.5 + noiseIQ(134.34 + _CosTime.y * 1000)) * (1 / (fade * 5));
		fixed offsetNoise2 = (-0.5 + noiseIQ(54.12 + _CosTime.y * 1000)) * (1 / (fade * 5));

		fixed f = length(float3(sin(p.x * 1)  , p.y * nosie + offsetNoise * 2, p.z * nosie + offsetNoise2 * 2)) - 1.8;

		fixed radialMult = 0.7 * (fade - 0.5) * nosie;
		fixed fInv = length(float3(sin(p.x) * 0.6, p.y* radialMult, p.z * radialMult)) - 0.8;

		fixed fS =(length(fixed3(nosie,0,0) + float3(sin(1.5 + p.x * 2), p.y + offsetNoise * 0.3, p.z + offsetNoise2 * 0.3)) - 0.9);

		if (f < 0)
			f = -1-f;


			//d = f + f1 + f2 + f3;

			//fixed d = max(f * 1, -fInv * 3);
			fixed d = max(f * 2, -fInv * 2);
			d = max(d, fade);
			 d = fOpUnionRound(d, fS * 4, 1);
			 d = max(d, -0.4 + fade * 3);

		//d = fog2;
		//float d = max(fog1, - fogInv);

		/*
		float mask = step(d, 0);

		d = lerp(0, -1, mask);

		d = max(d, -fog2);*/

		//d += fog2;

		//d = max(d, fade);

		//d = max(d, fade);
		//d = fOpDifferenceRound(fac, fade, 10);

		return fixed3(_Move,0,0) + d;
	}
	
	float mapExhaust2(float3 p)
	{
		float size = 2.5;
		float c = 0;

		c = pmod1(p.x, size);

		float sphere1 = fSphere(p + fixed3(0, 0.5, 0), 2);
		float sphere2 = fSphere(p + fixed3(0, -0.5, 0), 2);

		float disc = max(sphere1, sphere2);

		float box = fBox(p, fixed3(1,1,1));
		float sphere = fSphere(p, 1);
		
		return disc;
	}

	float mapw(float3 p)
	{
		return sphere(p, float3(0,0,0), 10);
	}

	float mapBreakout(float3 p)
	{

		float sphere1 = sphere(p, float3(0, 0, 0), 1);
		//float sphere1 = sphere(noiseIQ(p), float3(0, 0, 0), 1);

		//float noiseSphere = max(noiseIQ(p*10), -sphere(p, float3(0, 0, 0), 1));

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

	fixed3 _FresnelColor;
	fixed _FresnelPower;

	fixed4 _FogColor1;
	fixed4 _FogColor2;

	fixed4 renderSurface(float3 p)
	{
		float3 n = normal(p);
		return simpleLambert(n) + lambertLight(n, _Light2Dir, _Light2Color) + fresnelLight(n, _FresnelColor, _FresnelPower);
	}

	fixed4 renderSurface2(float3 p)
	{
		float3 n = normal(p);

		fixed4 c;
		c.rgb = n;
		c.a = 1;

		return c;
	}

	fixed4 renderDepth(float p, float depth)
	{
		float d = depth * _FogDensity;

		fixed4 c;

		// COLOR LERP RENDERING
		//c.rgb = lerp(_FogColor1, _FogColor2, d);

		// RAMP RENDERING
		c.rgb = tex2D(_RampTex, float2(d, 0.5)).rgb;

		c.a = d;

		//float3 n = normal(p);

		return c;
	}

	fixed4 renderCombined(float3 p, bool surface, float depth)
	{
		//return renderSurface(p);
		return (surface ? renderSurface(p) : 0) + renderDepth(p, depth);
	}



	// --------
	// RAYMARCH
	// --------

	fixed4 raymarchOriginal(float3 position, float3 direction)
	{
		for (int i = 0; i < STEPS; i++)
		{
			float distance = mapButtocks(position);

			if (distance < MIN_DISTANCE)
				return renderSurface(position);

			position += distance * direction;
		}
		return fixed4(0, 0, 0, 0);
	}

	fixed4 raymarchO(float3 position, float3 direction)
	{
		for (int i = 0; i < STEPS; i++)
		{
			float distance = map(position);
			if (distance < MIN_DISTANCE)
				return renderSurface(position);

			position += distance * direction;
		}
		return fixed4(1, 1, 1, 1);
	}
	
	fixed4 raymarchCombined(float3 position, float3 direction)
	{
		float depth = 0;

		for (int i = 0; i < FOGSTEPS; i++)
		{
			float surfDistance = map(position);

			if (surfDistance < MIN_DISTANCE)
				return renderCombined(position, true, depth);


			float fogDistance = mapFog(position);

			if (fogDistance < MIN_DISTANCE)
				depth += 1;

			position += direction * STEP_SIZE;
		}

		if (depth == 0)
			return fixed4(0, 0, 0, 0);

		return renderCombined(position, false, depth);
	}

	fixed4 raymarchConstantDepth(float3 position, float3 direction)
	{
		float depth = 0;

		for (int i = 0; i < FOGSTEPS; i++)
		{
			float distance = mapExhaust(position);

			if (distance < MIN_DISTANCE)
				depth += 1;

			position += direction * STEP_SIZE * 10;// *i * 0.05;
		}

		if (depth == 0)
			return fixed4(0, 0, 0, 0);

		return renderDepth(position, depth);
	}

	fixed4 raymarchDensity(float3 position, float3 direction)
	{
		float depth = 0;

		for (int i = 0; i < FOGSTEPS; i++)
		{
			float distance = mapShockRot(position);

			if (distance < MIN_DISTANCE)
				depth += - distance * 3;

			position += direction * STEP_SIZE * 10;// *i * 0.05;
		}

		if (depth == 0)
			return fixed4(0, 0, 0, 0);

		return renderDepth(position, depth);
	}

	fixed4 raymarchConstant(float3 position, float3 direction)
	{

			for (int i = 0; i < STEPS; i++)
			{
				float distance = map(position);

				if (distance < MIN_DISTANCE)
					return renderSurface(position);

				position += direction * STEP_SIZE;
			}

			return fixed4(0, 0, 0, 1); // White
	}

	fixed4 raymarch(float3 position, float3 direction)
	{
		float depth = 0;

		for (int i = 0; i < STEPS; i++)
		{
			float distance = map(position);

			if (distance < MIN_DISTANCE)
				depth += 1;

			position += distance * direction;
		}

		if (depth == 0)
			return fixed4(0, 0, 0, 0);

		return renderDepth(position, depth);
	}

	fixed4 frag(v2f i) : SV_Target
	{
		float3 worldPosition = i.wPos;
		float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);

		return raymarchDensity(i.wPos, viewDirection);
	}


		ENDCG
	}
	}
}
