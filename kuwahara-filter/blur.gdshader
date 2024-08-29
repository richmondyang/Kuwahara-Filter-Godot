shader_type canvas_item;

uniform sampler2D _MainTex : hint_screen_texture, repeat_disable, filter_nearest;

float gaussian(float sigma, float pos)
{
	return (1.0f / sqrt(2.0f * PI * sigma * sigma)) * exp(-(pos * pos) / (2.0f * sigma * sigma));
}

vec4 blur(/*vec4 tensor, */vec2 uv, vec2 d)
{
	int kernelRadius = 5;
	
	vec4 col = vec4(0.0);
	float kernelSum = 0.0;
	
	for (int x = -kernelRadius; x <= kernelRadius; x++)
	{
		vec4 c = texture(_MainTex, uv + vec2(float(x), 0.0) * d.xy);
		float gauss = gaussian(2.0, float(x));
		
		col += c * gauss;
		kernelSum += gauss;
	}
	
	col = col / kernelSum;
	
	for (int y = -kernelRadius; y <= kernelRadius; y++)
	{
		vec4 c = texture(_MainTex, uv + vec2(0.0, float(y)) * d.xy);
		float gauss = gaussian(2.0, float(y));
		
		col += c * gauss;
		kernelSum += gauss;
	}
	
	return vec4(col / kernelSum);
}

void fragment()
{
	COLOR = blur(UV, SCREEN_PIXEL_SIZE);
}