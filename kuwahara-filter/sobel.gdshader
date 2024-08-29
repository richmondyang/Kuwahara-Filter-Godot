shader_type canvas_item;

uniform sampler2D _MainTex : hint_screen_texture, repeat_disable, filter_nearest;

vec4 sobel(vec2 screen_size, vec2 uv)
{
	// Calculate Eigenvectors and Eigenvalues
	// Calculate Sobel to approximate structure tensor
	vec2 d = screen_size.xy;
	
	vec3 sobel_x = (
		1.0f * texture(_MainTex, uv + vec2(-d.x, -d.y)).rgb +
		2.0f * texture(_MainTex, uv + vec2(-d.x,  0.0)).rgb +
		1.0f * texture(_MainTex, uv + vec2(-d.x,  d.y)).rgb +
		-1.0f * texture(_MainTex, uv + vec2(d.x, -d.y)).rgb +
		-2.0f * texture(_MainTex, uv + vec2(d.x,  0.0)).rgb +
		-1.0f * texture(_MainTex, uv + vec2(d.x,  d.y)).rgb
		) / 4.0f;
	vec3 sobel_y = (
		1.0f * texture(_MainTex, uv + vec2(-d.x, -d.y)).rgb +
		2.0f * texture(_MainTex, uv + vec2( 0.0, -d.y)).rgb +
		1.0f * texture(_MainTex, uv + vec2( d.x, -d.y)).rgb +
		-1.0f * texture(_MainTex, uv + vec2(-d.x, d.y)).rgb +
		-2.0f * texture(_MainTex, uv + vec2( 0.0, d.y)).rgb +
		-1.0f * texture(_MainTex, uv + vec2( d.x, d.y)).rgb
		) / 4.0f;
		
	// Structure Tensor (4x4 matrix)
	return vec4(dot(sobel_x, sobel_x), dot(sobel_y, sobel_y), dot(sobel_x, sobel_y), 1.0);
}

void fragment()
{
	COLOR = sobel(SCREEN_PIXEL_SIZE, UV);
}