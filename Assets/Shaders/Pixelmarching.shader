// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Image/Pixelmarching"
{
	Properties
	{
	}
	SubShader
	{
		// remove for image effect
		//Tags{ "RenderType" = "Transparent" "Queue" = "Transparent" }
		// No culling or depth
		Cull Off ZWrite Off ZTest Always

		// remove for image effect
		//Blend One One

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "LeonsPerlin.cginc"

			#define STEPS 1024
			#define FOG_STEPS  10000
			#define STEP_SIZE 0.01
			#define MIN_DISTANCE 0.001 // 0.0001

			uniform float4x4 _FrustumCornersES;
			uniform sampler2D _MainTex;
			uniform float4 _MainTex_TexelSize;
			uniform float4x4 _CameraInvViewMatrix;

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;

				float3 wPos : TEXCOORD1;	// World position
				float3 ray : TEXCOORD2;
			};

			v2f vert(appdata v)
			{
				v2f o;

				half index = v.vertex.z;
				v.vertex.z = 0.1;

				o.vertex = mul(UNITY_MATRIX_MVP, v.vertex);
				o.wPos = mul(UNITY_MATRIX_MVP, v.vertex).xyz;
				o.uv = v.uv.xy;

#if UNITY_UV_STARTS_AT_TOP
				if (_MainTex_TexelSize.y < 0)
					o.uv.y = 1 - o.uv.y;
#endif

				// Get the eyespace view ray (normalized)
				o.ray = _FrustumCornersES[(int)index].xyz;

				// Transform the ray from eyespace to worldspace
				// Note: _CameraInvViewMatrix was provided by the script
				o.ray = mul(_CameraInvViewMatrix, o.ray);

				return o;
			}

			// MAPPING


			float iSphere(float3 p, float3 r)
			{
				return length(p) - r;
			}

			float nSphere(float3 p, float3 r, float depth)
			{
				return length(p) - (r + noiseIQ(p * depth));
			}

			float map(float3 p)
			{
				float3 orbit = float3(_CosTime.x, 0, _SinTime.x) * 20;

				float n1 = iSphere(p, 11);
				float n2 = nSphere(p + orbit, 2, 1);
				float n3 = nSphere(p, 11, 1.2);
				float m = min(min(n1, n2), n3);
				
				return m;
			}

			float solidmap(float3 p)
			{
				float n1 = nSphere(p, 9, 1);
				float n2 = iSphere(p, 9.5);
				float m = min(n1, n2);
				
				return m;
			}

			// LIGHTING

			float3 solidnormal(float3 p)
			{
				const float eps = 0.01;

				return normalize 
				(float3
					(solidmap(p + float3(eps, 0, 0)) - solidmap(p - float3(eps, 0, 0)),
						solidmap(p + float3(0, eps, 0)) - solidmap(p - float3(0, eps, 0)),
						solidmap(p + float3(0, 0, eps)) - solidmap(p - float3(0, 0, eps))
						)
				);
			}

			float3 fognormal(float3 p)
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

			fixed4 _LightColor0;

			fixed4 lambert(fixed3 normal)
			{
				fixed3 lightDir = _WorldSpaceLightPos0.xyz;	// Light direction
				fixed3 lightCol = _LightColor0.rgb;		// Light color

				fixed NdotL = max(dot(normal, -lightDir), 0);
				fixed4 c = 0;
				c.rgb = NdotL;
				//c.rgb *= lightCol;
				c.a = 1;
				return c;
			}

			fixed4 renderSurface(float3 n)
			{
				fixed4 c = 0;

				c += lambert(n);

				return c;
			}

			// RAYMARCHING

			// surface raycasting
			fixed4 raymarch(float3 position, float3 direction)
			{
				for (int i = 0; i < STEPS; i++)
				{
					float distance = map(position);

					if (distance < MIN_DISTANCE)
					{
						// for testing, returns cyan if it hits anything
						//return fixed4(0, 1, 1, 1);

						return renderSurface(solidnormal(position));
					}

					position += distance * direction;
				}

				return fixed4(0, 0, 0, 0);
			}

			// with depth
			fixed4 depthmarch(float3 position, float3 direction)
			{
				float surf = 0;
				float fog = 0;

				for (int i = 0; i < FOG_STEPS; i++)
				{
					float distance = map(position);
					float solidDistance = solidmap(position);

					if (solidDistance < MIN_DISTANCE)
					{
						surf = renderSurface(solidnormal(position));

						return surf + fog;
					}
					
					if (distance < MIN_DISTANCE)
					{
						if (fog >= 1) return surf + fog; 

						fog += 0.002 * (renderSurface(fognormal(position)));
					}

					position += direction * STEP_SIZE;
				}

				return surf + fog;
			}

			// FRAGMENT

			fixed4 frag(v2f i) : SV_Target
			{
				float3 worldPosition = i.wPos;
				//worldPosition = 0;
				float3 viewDirection = normalize(worldPosition - _WorldSpaceCameraPos);
				//float3 viewDir = UNITY_MATRIX_IT_MV[2].xyz;
				float3 viewDir = i.ray;
				//fixed4 rm = raymarch(_WorldSpaceCameraPos, viewDir);
				fixed4 rm = depthmarch(_WorldSpaceCameraPos, viewDir);

				fixed4 c = 0;

				//c += rm;
				c = rm;
				//c.a = 1;

				//c = fixed4(i.ray, 1);

				// Testing
				//c += half4(i.uv, 1, 1) * 10;

				return c;
			}
			ENDCG
		}
	}
}
