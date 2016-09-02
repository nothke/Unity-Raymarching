// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Unlit/VolumentricRendering01"
{
	Properties
	{
		_Radius("Radius", float) = 1
		_Centre("Centre", vector) = (0,0,0)
	}
		SubShader
	{
		// No culling or depth
		//Cull Off ZWrite Off ZTest Always

		Pass
		{
		CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float _Radius;
			float3 _Centre;

			#define STEPS 128
			#define STEP_SIZE 0.01

			struct appdata {
				float4 vertex : POSITION;
			};

			struct v2f {
				float4 vertex : SV_POSITION;
				float3 wPos : TEXCOORD1; // World Position
			};

			v2f vert(appdata v) {
				v2f o;
				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.wPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				return o;
			}

			bool sphereHit(float3 p) {
				return distance(p, _Centre) < _Radius;
			}

			bool raymarchHit(float3 position, float3 direction) {
				for (int i = 0; i < STEPS; i++) {
					if (sphereHit(position)) {
						return true;
					}
					position += direction * STEP_SIZE;
				}
				return false;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float3 worldPosition = i.wPos;
				float3 viewDirection = normalize(i.wPos - _WorldSpaceCameraPos);

				if (raymarchHit(worldPosition, viewDirection)) {
					return fixed4(1,0,0,1);
				}
				else {
					return fixed4(1,1,1,1);
				}
			}
		ENDCG
		}
	}
}