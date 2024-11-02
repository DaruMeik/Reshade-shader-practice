/*
Heavily refered from Acerola Kuwahara Shader. Rebuilt mostly from the video + paper provied.
Credit: https://github.com/GarrettGunnell
*/


#ifndef MEIK_KUWAHARA_POSTPROCESSOR
#define MEIK_KUWAHARA_POSTPROCESSOR 0

static const int bayer[4 * 4] = {
	0, 8, 2, 10,
	12, 4, 14, 6,
	3, 11, 1, 9,
	15, 7, 13, 5
};

uniform float _NoiseSpread <
	ui_min = 0.0; ui_max = 1.0;
	ui_type = "slider";
	ui_label = "Dithering Noise Spread";
> = 0.5;

uniform float _Sharpness <
	ui_min = 0.0; ui_max = 1.0;
	ui_type = "slider";
	ui_label = "Sharpness";
> = 0.5;

uniform uint _KernelSize <
	ui_min = 2; ui_max = 10;
	ui_type = "slider";
	ui_label = "Radius";
	ui_tooltip = "Radius of the kuwahara filter kernel";
> = 2;

uniform float _ZeroCrossing <
	ui_min = 0.01f; ui_max = 2.0f;
	ui_category_closed = true;
	ui_category = "Generalized Kuwahara Settings";
	ui_type = "drag";
	ui_label = "Zero Crossing";
	ui_tooltip = "How much sectors overlap with each other";
> = 0.58f;

uniform float _Q <
	ui_min = 0; ui_max = 18;
	ui_category_closed = true;
	ui_category = "Generalized Kuwahara Settings";
	ui_type = "drag";
	ui_label = "Sharpness";
	ui_tooltip = "Adjusts sharpness of the color segments";
> = 8;

#ifndef SECTORS_N
# define SECTORS_N 8
#endif

texture2D mainTexColorBuffer : COLOR;

sampler2D _MainTex
{
	Texture = mainTexColorBuffer;
};

struct VertexInput {
	uint id : SV_VertexID;
};

struct Interpolators
{
	float4 position : SV_POSITION;
	float2 uv : TEXCOORD0;
};

void MyVertexShader(VertexInput v, out Interpolators i)
{
	i.uv.x = (v.id == 2) ? 2.0 : 0.0;
	i.uv.y = (v.id == 1) ? 2.0 : 0.0;
	i.position = float4(i.uv * float2(2, -2) + float2(-1, 1), 0, 1);
}

float4 SharpeningShader(Interpolators i) : SV_Target{
	float4 color = tex2D(_MainTex, i.uv);

	// Sharpness
	float4 n = tex2D(_MainTex, i.uv + float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * float2(0, 1));
	float4 e = tex2D(_MainTex, i.uv + float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * float2(1, 0));
	float4 w = tex2D(_MainTex, i.uv + float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * float2(-1, 0));
	float4 s = tex2D(_MainTex, i.uv + float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * float2(0, -1));

	float4 neighbor = (n + e + w + s) * _Sharpness * -1;
	color = color * _Sharpness * 4 + color;
	color += neighbor;

	return color;
}

float GetLuminance(float3 color) {
	return dot(color,float3(0.21f, 0.72f, 0.07f));
}

float4 SampleQuadrant(float2 uv, int x0, int y0, int x1, int y1, int n) {
	float lum_sum = 0.0;
	float lum_sum2 = 0.0;
	float3 col_sum = float3(0.0, 0.0, 0.0);

	for (int x = x0; x <= x1; ++x) {
		for (int y = y0; y <= y1; ++y) {
			float3 n_color = tex2D(_MainTex,
				uv + float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * float2(x, y)).rgb;
			col_sum += n_color;

			float n_lum = GetLuminance(n_color);
			lum_sum += n_lum;
			lum_sum2 += n_lum * n_lum;
		}
	}

	float mean = lum_sum / n;
	float std = lum_sum2 - 2 * mean * lum_sum + n * mean * mean;

	return float4(col_sum.r / n, col_sum.g / n, col_sum.b / n, std);
}

float4 KuwaharaFilterShader(Interpolators i) : SV_Target
{
	int radius = _KernelSize / 2;
	int windowSize = 2 * radius + 1;
	int quadrantSize = radius + 1;
	int numSamples = quadrantSize * quadrantSize;

	float4 q1 = SampleQuadrant(i.uv, -radius, -radius, 0, 0, numSamples);
	float4 q2 = SampleQuadrant(i.uv, 0, -radius, radius, 0, numSamples);
	float4 q3 = SampleQuadrant(i.uv, 0, 0, radius, radius, numSamples);
	float4 q4 = SampleQuadrant(i.uv, -radius, 0, 0, radius, numSamples);


	float min_std = min(q1.a, min(q2.a, min(q3.a, q4.a)));
	int4 q = float4(q1.a, q2.a, q3.a, q4.a) == min_std;
	
	return saturate(float4((q1.rgb * q.x + q2.rgb * q.y + q3.rgb * q.z + q4.rgb * q.w) / dot(q, 1), 1.0f));
}

technique OriginalKuwaharaFilter < ui_tooltip = "Original Kuwahara Shader"; > 
{
	pass KuwaharaFilterPass {
		VertexShader = MyVertexShader;
		PixelShader = KuwaharaFilterShader;
	}
}

float4 GeneralizedKuwaharaFilterShader(Interpolators i) : SV_Target
{
	int k;
	float4 m[SECTORS_N];
	float3 s[SECTORS_N];
	int radius = _KernelSize / 2;

	float zeta = 2.0f / radius;

	float zeroCross = _ZeroCrossing;
	float sinZeroCross = sin(zeroCross);
	float eta = (zeta + cos(sinZeroCross)) / (sinZeroCross * sinZeroCross);

	// Init vector
	for (k = 0; k < SECTORS_N; ++k) {
		m[k] = 0.0f;
		s[k] = 0.0f;
	}

	[loop]
	for (int x = -radius; x <= radius; ++x) {
		[loop]
		for (int y = -radius; y <= radius; ++y) {
			float2 v = float2(x, y) / _KernelSize;
			float3 c = tex2D(_MainTex, i.uv + float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT) * float2(x, y)).rgb;
			float sum = 0;
			float w[SECTORS_N];
			float z, vxx, vyy;

			// Polynomial Weight
			vxx = zeta - eta * v.x * v.x;
			vyy = zeta - eta * v.y * v.y;

			z = max(0, v.y + vxx); 
			w[0] = z * z; sum += w[0];

			z = max(0, -v.x + vyy);
			w[2] = z * z; sum += w[2];

			z = max(0, -v.y + vxx);
			w[4] = z * z; sum += w[4];
			z = max(0, v.x + vyy); 
			w[6] = z * z; sum += w[6];
			
			v = sqrt(2) / 2 * float2(v.x - v.y, v.x + v.y);
			vxx = zeta - eta * v.x * v.x;
			vyy = zeta - eta * v.y * v.y;

			z = max(0, v.y + vxx); 
			w[1] = z * z; sum += w[1];
			z = max(0, -v.x + vyy); 
			w[3] = z * z; sum += w[3];
			z = max(0, -v.y + vxx); 
			w[5] = z * z; sum += w[5];
			z = max(0, v.x + vyy); 
			w[7] = z * z; sum += w[7];

			float g = exp(-3.125 * dot(v, v)) / sum;
			for (int k = 0; k < SECTORS_N; ++k) {
				float wk = w[k] * g;
				m[k] += float4(c * wk, wk);
				s[k] += c * c * wk;
			}
		}
	}

	float4 output = 0;
	for (k = 0; k < SECTORS_N; k++) {
		m[k].rgb /= m[k].w;
		s[k] = abs(s[k] / m[k].w - m[k].rgb * m[k].rgb);

		float sigma2 = s[k].r + s[k].g + s[k].b;
		float w = 1.0f / (1.0f + pow(1000.0f * sigma2, 0.5f * _Q));

		output += float4(m[k].rgb * w, w);
	}

	output /= output.w;

	return output;
}

float4 DitheringShader(Interpolators i) : SV_Target{

	float4 color = tex2D(_MainTex, i.uv);

	// Dithering
	int x = (i.uv.x * BUFFER_WIDTH) % 4;
	int y = (i.uv.y * BUFFER_HEIGHT) % 4;
	float noise = bayer[x + 4 * y] * (1.0 / 16.0) - 0.5;
	color += noise * _NoiseSpread;

	// Quanitization
	color = floor(color * 15 + 0.5) / 15.0;

	return color;
}

technique GeneralizedKuwaharaFilter < ui_tooltip = "Generalized Kuwahara Shader"; >
{
	pass SharpnessPass {
		VertexShader = MyVertexShader;
		PixelShader = SharpeningShader;
	}
	pass GeneralizedKuwaharaFilterPass {
		VertexShader = MyVertexShader;
		PixelShader = GeneralizedKuwaharaFilterShader;
	}
}
#endif
