//!DESC Godess2x-v3.2-Upscale-DoG-x2-Luma
//!HOOK MAIN
//!BIND HOOKED
//!SAVE LINELUMA
//!COMPONENTS 1

float get_luma(vec4 rgba) {
	return dot(vec4(0.299, 0.587, 0.114, 0.0), rgba);
}

vec4 hook() {
    return vec4(get_luma(HOOKED_tex(HOOKED_pos)), 0.0, 0.0, 0.0);
}

//!DESC Godess2x-v3.2-Upscale-DoG-x2-Kernel-X
//!WHEN OUTPUT.w MAIN.w / 1.200 > OUTPUT.h MAIN.h / 1.200 > *
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINELUMA
//!SAVE GAUSS_X2
//!COMPONENTS 3

#define L_tex LINELUMA_tex

float max3v(float a, float b, float c) {
	return max(max(a, b), c);
}
float min3v(float a, float b, float c) {
	return min(min(a, b), c);
}

vec2 minmax3(vec2 pos, vec2 d) {
	float a = L_tex(pos - d).x;
	float b = L_tex(pos).x;
	float c = L_tex(pos + d).x;
	
	return vec2(min3v(a, b, c), max3v(a, b, c));
}

float lumGaussian7(vec2 pos, vec2 d) {
	float g = (L_tex(pos - (d + d)).x + L_tex(pos + (d + d)).x) * 0.06136;
	g = g + (L_tex(pos - d).x + L_tex(pos + d).x) * 0.24477;
	g = g + (L_tex(pos).x) * 0.38774;
	
	return g;
}


vec4 hook() {
    return vec4(lumGaussian7(HOOKED_pos, vec2(HOOKED_pt.x, 0)), minmax3(HOOKED_pos, vec2(HOOKED_pt.x, 0)), 0);
}


//!DESC Godess2x-v3.2-Upscale-DoG-x2-Kernel-Y
//!WHEN OUTPUT.w MAIN.w / 1.200 > OUTPUT.h MAIN.h / 1.200 > *
//!HOOK MAIN
//!BIND HOOKED
//!BIND GAUSS_X2
//!SAVE GAUSS_X2
//!COMPONENTS 3

#define L_tex GAUSS_X2_tex

float max3v(float a, float b, float c) {
	return max(max(a, b), c);
}
float min3v(float a, float b, float c) {
	return min(min(a, b), c);
}

vec2 minmax3(vec2 pos, vec2 d) {
	float a0 = L_tex(pos - d).y;
	float b0 = L_tex(pos).y;
	float c0 = L_tex(pos + d).y;
	
	float a1 = L_tex(pos - d).z;
	float b1 = L_tex(pos).z;
	float c1 = L_tex(pos + d).z;
	
	return vec2(min3v(a0, b0, c0), max3v(a1, b1, c1));
}

float lumGaussian7(vec2 pos, vec2 d) {
	float g = (L_tex(pos - (d + d)).x + L_tex(pos + (d + d)).x) * 0.06136;
	g = g + (L_tex(pos - d).x + L_tex(pos + d).x) * 0.24477;
	g = g + (L_tex(pos).x) * 0.38774;
	
	return g;
}


vec4 hook() {
    return vec4(lumGaussian7(HOOKED_pos, vec2(0, HOOKED_pt.y)), minmax3(HOOKED_pos, vec2(0, HOOKED_pt.y)), 0);
}

//!DESC Godess2x-v3.2-Upscale-DoG-x2-Apply
//!WHEN OUTPUT.w MAIN.w / 1.200 > OUTPUT.h MAIN.h / 1.200 > *
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINELUMA
//!BIND GAUSS_X2
//!WIDTH MAIN.w 2 *
//!HEIGHT MAIN.h 2 *

#define STRENGTH 0.8 //De-blur proportional strength, higher is sharper.

#define L_tex LINELUMA_tex

vec4 hook() {

	float c = (L_tex(HOOKED_pos).x - GAUSS_X2_tex(HOOKED_pos).x) * STRENGTH;
	float cc = clamp(c + L_tex(HOOKED_pos).x, GAUSS_X2_tex(HOOKED_pos).y, GAUSS_X2_tex(HOOKED_pos).z) - L_tex(HOOKED_pos).x;
	
	//This trick is only possible if the inverse Y->RGB matrix has 1 for every row... (which is the case for BT.709)
	//Otherwise we would need to convert RGB to YUV, modify Y then convert back to RGB.
	return HOOKED_tex(HOOKED_pos) + cc;
}



