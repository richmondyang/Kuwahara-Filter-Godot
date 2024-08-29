shader_type canvas_item;

uniform sampler2D _MainTex : hint_screen_texture;

uniform int _KernelSize = 6;
uniform int _N = 8;

uniform float _Hardness = 8;
uniform float _Q = 8;
uniform float _Alpha = 1;
uniform float _ZeroCrossing = 0.58;
uniform float _Zeta = 0.1;

float gaussian(float sigma, float pos)
{
	return (1.0f / sqrt(2.0f * PI * sigma * sigma)) * exp(-(pos * pos) / (2.0f * sigma * sigma));
}

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

vec4 blur(vec2 uv, vec2 d)
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

vec4 scaling_factor(vec4 t)
{
	// Calculate Eigenvalues
	float lambda1 = 0.5 * (t.x + t.y + sqrt(t.x * t.x - 2.0 * t.x * t.y + t.y * t.y + 4.0 * t.z * t.z));
	float lambda2 = 0.5 * (t.x + t.y - sqrt(t.x * t.x - 2.0 * t.x * t.y + t.y * t.y + 4.0 * t.z * t.z));

	// Calculate and Normalize Eigenvector
	vec2 v = vec2(lambda1 - t.x, -t.z);
	vec2 n = vec2(0.0, 0.0);
	
	if (length(v) > 0.0)
	{
		n = normalize(v);
	}
	else
	{
		n = vec2(0.0, 1.0);
	}
	
	// Angle relative to x-axis of Eigenvector
	float phi = -atan(n.y / n.x);
	
	// Scaling Factor
	float A = 0.0;
	
	if (lambda1 + lambda2 > 0.0)
	{
		A = (lambda1 - lambda2) / (lambda1 + lambda2);
	}
	
	// Kernel deform factors
	return vec4(n, phi, A);
}

vec4 kuwahara(vec2 n, float phi, float A, vec2 d, vec2 uv)
{
	// Kuwahara Filter
	int radius = _KernelSize / 2;
	float a = float((radius)) * clamp((_Alpha + A) / _Alpha, 0.1, 2.0);
	float b = float((radius)) * clamp(_Alpha / (_Alpha + A), 0.1, 2.0);
	
	// Displace kernel
	float cos_phi = cos(phi);
	float sin_phi = sin(phi);
	
	mat2 R = mat2(vec2(cos_phi, -sin_phi), vec2(sin_phi, cos_phi));
	mat2 S = mat2(vec2(0.5 / a, 0.0), vec2(0.0, 0.5 / b));
	
	mat2 SR = matrixCompMult(S, R);
	
	int max_x = int(sqrt(a * a * cos_phi * cos_phi + b * b * sin_phi * sin_phi));
	int max_y = int(sqrt(a * a * sin_phi * sin_phi + b * b * cos_phi * cos_phi));
	
	float sinZeroCross = sin(_ZeroCrossing);
	float eta = (_Zeta + cos(_ZeroCrossing)) / (sinZeroCross * sinZeroCross);
	
	vec4 m[8];
	vec3 s[8];
	
	for (int k = 0; k < _N; k++)
	{
		m[k] = vec4(0.0);
		s[k] = vec3(0.0);
	}
	
	for (int y = -max_y; y <= max_y; y++)
	{
		for(int x = -max_x; x <= max_x; x++)
		{
			vec2 vec = SR * vec2(float(x), float(y));
			if (dot(vec, vec) <= 0.25)
			{
				vec3 c = texture(_MainTex, uv + vec2(float(x), float(y)) * d).rgb;
				c = clamp(c, 0.0, 1.0);
				float sum = 0.0;
				float w[8];
				float z, vxx, vyy;
				
				// Polynomial Weights
				vxx = _Zeta - eta * vec.x * vec.x;
				vyy = _Zeta - eta * vec.y * vec.y;
				z = max(0, vec.y + vxx); 
				w[0] = z * z;
				sum += w[0];
				z = max(0, -vec.x + vyy); 
				w[2] = z * z;
				sum += w[2];
				z = max(0, -vec.y + vxx); 
				w[4] = z * z;
				sum += w[4];
				z = max(0, vec.x + vyy); 
				w[6] = z * z;
				sum += w[6];
				vec = sqrt(2.0) / 2.0 * vec2(vec.x - vec.y, vec.x + vec.y);
				vxx = _Zeta - eta * vec.x * vec.x;
				vyy = _Zeta - eta * vec.y * vec.y;
				z = max(0, vec.y + vxx); 
				w[1] = z * z;
				sum += w[1];
				z = max(0, -vec.x + vyy); 
				w[3] = z * z;
				sum += w[3];
				z = max(0, -vec.y + vxx); 
				w[5] = z * z;
				sum += w[5];
				z = max(0, vec.x + vyy); 
				w[7] = z * z;
				sum += w[7];
				
				float g = exp(-3.125 * dot(vec, vec)) / sum;
				
				for (int k = 0; k < 8; k++)
				{
					float wk = w[k] * g;
					m[k] += vec4(c * wk, wk);
					s[k] += c * c * wk;
				}
			}
		}
	}
	
	vec4 output = vec4(0.0);
    for (int k = 0; k < _N; ++k) 
	{
    	m[k].rgb /= m[k].w;
		s[k] = abs(s[k] / m[k].w - m[k].rgb * m[k].rgb);

		float sigma2 = s[k].r + s[k].g + s[k].b;
		float w = 1.0 / (1.0 + pow(_Hardness * 1000.0 * sigma2, 0.5 * _Q));

		output += vec4(m[k].rgb * w, w);
	}
	return clamp(output / output.w, 0.0, 1.0);
}

void fragment() 
{
	vec4 blur = blur(UV, SCREEN_PIXEL_SIZE);
	COLOR = blur;
	
	vec4 tensor = sobel(SCREEN_PIXEL_SIZE, UV);
	vec4 fac = scaling_factor(blur);
	vec4 output = kuwahara(fac.xy, fac.z, fac.w, SCREEN_PIXEL_SIZE, UV);

	COLOR = output;
}