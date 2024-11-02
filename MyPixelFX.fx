#ifndef MY_PIXEL_POSTPROCESSOR
#define MY_PIXEL_POSTPROCESSOR 0

static const int bayer[4 * 4] = {
	0, 8, 2, 10,
	12, 4, 14, 6,
	3, 11, 1, 9,
	15, 7, 13, 5
};

uniform float _NoiseSpread <
	ui_min = 0.0; ui_max = 1.0;
ui_category_closed = false;
ui_category = "Pixelate Setting";
ui_type = "slider";
ui_label = "Dithering Noise Spread";
> = 0.5;

uniform float _Sharpness <
	ui_min = 0.0; ui_max = 1.0;
ui_category_closed = false;
ui_category = "Pixelate Setting";
ui_type = "slider";
ui_label = "Sharpness";
> = 0.5;

texture2D mainTexColorBuffer : COLOR;

texture2D targetTex
{
	// The texture dimensions (default: 1x1).
	Width = BUFFER_WIDTH / 1; // Used with texture1D, texture2D and texture3D
	Height = BUFFER_HEIGHT / 1; // Used with texture2D and texture3D

	// The number of mipmaps including the base level (default: 1).
	MipLevels = 1;

	// The internal texture format (default: RGBA8).
	// Available formats:
	//   R8, R16, R16F, R32F, R32I, R32U
	//   RG8, RG16, RG16F, RG32F
	//   RGBA8, RGBA16, RGBA16F, RGBA32F
	//   RGB10A2
	Format = RGBA8;

	// Unspecified properties are set to the defaults shown here.
};

texture2D paletteTex <
	source = "../Textures/8x8.png";
> {
	Format = RGBA8;
	Width = 80;
	Height = 16;
};
sampler2D _MainTex
{
	// The texture to be used for sampling.
	Texture = mainTexColorBuffer;

// The method used for resolving texture coordinates which are out of bounds.
// Available values: CLAMP, MIRROR, WRAP or REPEAT, BORDER
AddressU = CLAMP;
AddressV = CLAMP;
AddressW = CLAMP;

// The magnification, minification and mipmap filtering types.
// Available values: POINT, LINEAR, ANISOTROPIC
MagFilter = POINT;
MinFilter = POINT;
MipFilter = POINT;

// The maximum mipmap levels accessible.
MinLOD = 0.0f;
MaxLOD = 1000.0f;

// An offset applied to the calculated mipmap level (default: 0).
MipLODBias = 0.0f;

};
sampler2D _TargetSample
{
	Texture = targetTex;
};
sampler2D _PaletteSample
{
	Texture = paletteTex;
};

struct VertexInput {
	uint id : SV_VertexID;
};

float4 RgbToLum(float4 col) {
	return sqrt(0.21 * col.r +
		0.72 * col.g+
		0.07 * col.b
	);
}

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

float4 DownsamplingShader(Interpolators i) : SV_Target{
	return tex2D(_MainTex, i.uv);
}

float4 FinalShader(Interpolators i) : SV_Target{

	float4 color = tex2D(_TargetSample, i.uv);

	// Dithering
	int x = (i.uv.x * BUFFER_WIDTH) % 4;
	int y = (i.uv.y * BUFFER_HEIGHT) % 4;
	float noise = bayer[x + 4 * y] * (1.0 / 16.0) - 0.5;
	color += noise * _NoiseSpread;

	// Quanitization
	color = RgbToLum(color);
	color = floor(color * 3 + 0.5) / 3.0;

	return tex2D(_PaletteSample, float2(color.r, 0));
}

technique PixelFilter < ui_tooltip = "Pixel filter! Credit: Acerola"; >
{
	pass SharpeningPass
	{
		VertexShader = MyVertexShader;
		PixelShader = SharpeningShader;
	}
	pass DownsamplingPass
	{
		VertexShader = MyVertexShader;
		PixelShader = DownsamplingShader;
		RenderTarget = targetTex;
	}
	pass RenderPass {
		VertexShader = MyVertexShader;
		PixelShader = FinalShader;
	}
}

#endif