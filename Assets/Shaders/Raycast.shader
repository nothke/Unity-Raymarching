// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/Raycast"
{
	Properties
	{
		_Radius("Radius", float) = 1
		_Centre("Centre", vector) = (0,0,0)
	}
		SubShader
	{
		Tags { "RenderType" = "Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			//#pragma multi_compile_fog

			#include "UnityCG.cginc"

			#define STEPS 64
			#define STEP_SIZE 0.01

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

			float3 _Centre;
			float _Radius;

			bool sphereHit(float3 p)
			{
				return distance(p,_Centre) < _Radius;
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


				if (raymarchHit(worldPosition, viewDirection))
					return fixed4(1,0,0,1); // Red if hit the ball
				else
					return fixed4(1,1,1,1); // White otherwise
			}


			ENDCG
		}
	}
}
