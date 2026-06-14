//!DESC Godess2x-v3.2-Thin-(Fast)-Luma
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

//!DESC Godess2x-v3.2-Thin-(Fast)-Sobel-X
//!HOOK MAIN
//!BIND LINELUMA
//!SAVE LINESOBEL
//!WIDTH HOOKED.w 2 /
//!HEIGHT HOOKED.h 2 /
//!COMPONENTS 2

vec4 hook() {
	float l = LINELUMA_texOff(vec2(-1.0, 0.0)).x;
	float c = LINELUMA_tex(LINELUMA_pos).x;
	float r = LINELUMA_texOff(vec2(1.0, 0.0)).x;
	
	float xgrad = (-l + r);
	float ygrad = (l + c + c + r);
	
	return vec4(xgrad, ygrad, 0.0, 0.0);
}


//!DESC Godess2x-v3.2-Thin-(Fast)-Sobel-Y
//!HOOK MAIN
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!WIDTH HOOKED.w 2 /
//!HEIGHT HOOKED.h 2 /
//!COMPONENTS 1

vec4 hook() {
	float tx = LINESOBEL_texOff(vec2(0.0, -0.5)).x;
	float cx = LINESOBEL_tex(LINESOBEL_pos).x;
	float bx = LINESOBEL_texOff(vec2(0.0, 0.5)).x;
	
	float ty = LINESOBEL_texOff(vec2(0.0, -0.5)).y;
	float by = LINESOBEL_texOff(vec2(0.0, 0.5)).y;
	
	float xgrad = (tx + cx + cx + bx) / 8.0;
	
	float ygrad = (-ty + by) / 8.0;
	
	//Computes the luminance's gradient
	float norm = sqrt(xgrad * xgrad + ygrad * ygrad);
	return vec4(pow(norm, 0.7));
}


//!DESC Godess2x-v3.2-Thin-(Fast)-Gaussian-X
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!WIDTH HOOKED.w 2 /
//!HEIGHT HOOKED.h 2 /
//!COMPONENTS 1

#define SPATIAL_SIGMA (1.0 * float(HOOKED_size.y) / 1080.0) //Spatial window size, must be a positive real number.

#define KERNELSIZE (max(int(ceil(SPATIAL_SIGMA * 2.0)), 1) * 2 + 1) //Kernel size, must be an positive odd integer.
#define KERNELHALFSIZE (int(KERNELSIZE/2)) //Half of the kernel size without remainder. Must be equal to trunc(KERNELSIZE/2).
#define KERNELLEN (KERNELSIZE * KERNELSIZE) //Total area of kernel. Must be equal to KERNELSIZE * KERNELSIZE.

float gaussian(float x, float s, float m) {
	float scaled = (x - m) / s;
	return exp(-0.5 * scaled * scaled);
}

float comp_gaussian_x() {

	float g = 0.0;
	float gn = 0.0;
	
	for (int i=0; i<KERNELSIZE; i++) {
		float di = float(i - KERNELHALFSIZE);
		float gf = gaussian(di, SPATIAL_SIGMA, 0.0);
		
		g = g + LINESOBEL_texOff(vec2(di, 0.0)).x * gf;
		gn = gn + gf;
		
	}
	
	return g / gn;
}

vec4 hook() {
    return vec4(comp_gaussian_x(), 0.0, 0.0, 0.0);
}


//!DESC Godess2x-v3.2-Thin-(Fast)-Gaussian-Y
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!WIDTH HOOKED.w 2 /
//!HEIGHT HOOKED.h 2 /
//!COMPONENTS 1

#define SPATIAL_SIGMA (1.0 * float(HOOKED_size.y) / 1080.0) //Spatial window size, must be a positive real number.

#define KERNELSIZE (max(int(ceil(SPATIAL_SIGMA * 2.0)), 1) * 2 + 1) //Kernel size, must be an positive odd integer.
#define KERNELHALFSIZE (int(KERNELSIZE/2)) //Half of the kernel size without remainder. Must be equal to trunc(KERNELSIZE/2).
#define KERNELLEN (KERNELSIZE * KERNELSIZE) //Total area of kernel. Must be equal to KERNELSIZE * KERNELSIZE.

float gaussian(float x, float s, float m) {
	float scaled = (x - m) / s;
	return exp(-0.5 * scaled * scaled);
}

float comp_gaussian_y() {

	float g = 0.0;
	float gn = 0.0;
	
	for (int i=0; i<KERNELSIZE; i++) {
		float di = float(i - KERNELHALFSIZE);
		float gf = gaussian(di, SPATIAL_SIGMA, 0.0);
		
		g = g + LINESOBEL_texOff(vec2(0.0, di)).x * gf;
		gn = gn + gf;
		
	}
	
	return g / gn;
}

vec4 hook() {
    return vec4(comp_gaussian_y(), 0.0, 0.0, 0.0);
}

//!DESC Godess2x-v3.2-Thin-(Fast)-Kernel-X
//!HOOK MAIN
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!WIDTH HOOKED.w 2 /
//!HEIGHT HOOKED.h 2 /
//!COMPONENTS 2

vec4 hook() {
	float l = LINESOBEL_texOff(vec2(-0.5, 0.0)).x;
	float c = LINESOBEL_tex(LINESOBEL_pos).x;
	float r = LINESOBEL_texOff(vec2(0.5, 0.0)).x;
	
	float xgrad = (-l + r);
	float ygrad = (l + c + c + r);
	
	return vec4(xgrad, ygrad, 0.0, 0.0);
}


//!DESC Godess2x-v3.2-Thin-(Fast)-Kernel-Y
//!HOOK MAIN
//!BIND LINESOBEL
//!SAVE LINESOBEL
//!WIDTH HOOKED.w 2 /
//!HEIGHT HOOKED.h 2 /
//!COMPONENTS 2

vec4 hook() {
	float tx = LINESOBEL_texOff(vec2(0.0, -0.5)).x;
	float cx = LINESOBEL_tex(LINESOBEL_pos).x;
	float bx = LINESOBEL_texOff(vec2(0.0, 0.5)).x;
	
	float ty = LINESOBEL_texOff(vec2(0.0, -0.5)).y;
	float by = LINESOBEL_texOff(vec2(0.0, 0.5)).y;
	
	float xgrad = (tx + cx + cx + bx) / 8.0;
	
	float ygrad = (-ty + by) / 8.0;
	
	//Computes the luminance's gradient
	return vec4(xgrad, ygrad, 0.0, 0.0);
}


//!DESC Godess2x-v3.2-Thin-(Fast)-Warp
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINESOBEL

#define STRENGTH 0.6 //Strength of warping for each iteration
#define ITERATIONS 1 //Number of iterations for the forwards solver, decreasing strength and increasing iterations improves quality at the cost of speed.

vec4 hook() {
	vec2 d = HOOKED_pt;
	
	float relstr = HOOKED_size.y / 1080.0 * STRENGTH;
	
	vec2 pos = HOOKED_pos;
	for (int i=0; i<ITERATIONS; i++) {
		vec2 dn = LINESOBEL_tex(pos).xy;
		vec2 dd = (dn / (length(dn) + 0.01)) * d * relstr; //Quasi-normalization for large vectors, avoids divide by zero
		pos -= dd;
	}
	
	return HOOKED_tex(pos);
	
}
