//!DESC Godess2x-v3.2-Darken-DoG-(HQ)-Luma
//!HOOK MAIN
//!BIND HOOKED
//!SAVE LINELUMA
//!WIDTH HOOKED.w 2 /
//!HEIGHT HOOKED.h 2 /
//!COMPONENTS 1

float get_luma(vec4 rgba) {
	return dot(vec4(0.299, 0.587, 0.114, 0.0), rgba);
}

vec4 hook() {
    return vec4(get_luma(HOOKED_tex(HOOKED_pos)), 0.0, 0.0, 0.0);
}

//!DESC Godess2x-v3.2-Darken-DoG-(VeryFast)-Gaussian-X
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINELUMA
//!SAVE LINEKERNEL
//!WIDTH HOOKED.w 4 /
//!HEIGHT HOOKED.h 4 /
//!COMPONENTS 1

#define SPATIAL_SIGMA (0.5 * float(HOOKED_size.y) / 1080.0) //Spatial window size, must be a positive real number.

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
		
		g = g + LINELUMA_texOff(vec2(di, 0.0)).x * gf;
		gn = gn + gf;
		
	}
	
	return g / gn;
}

vec4 hook() {
    return vec4(comp_gaussian_x(), 0.0, 0.0, 0.0);
}

//!DESC Godess2x-v3.2-Darken-DoG-(VeryFast)-Gaussian-Y
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINELUMA
//!BIND LINEKERNEL
//!SAVE LINEKERNEL
//!WIDTH HOOKED.w 4 /
//!HEIGHT HOOKED.h 4 /
//!COMPONENTS 1

#define SPATIAL_SIGMA (0.25 * float(HOOKED_size.y) / 1080.0) //Spatial window size, must be a positive real number.

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
		
		g = g + LINEKERNEL_texOff(vec2(0.0, di)).x * gf;
		gn = gn + gf;
		
	}
	
	return g / gn;
}

vec4 hook() {
    return vec4(min(LINELUMA_tex(HOOKED_pos).x - comp_gaussian_y(), 0.0), 0.0, 0.0, 0.0);
}

//!DESC Godess2x-v3.2-Darken-DoG-(VeryFast)-Gaussian-X
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINEKERNEL
//!SAVE LINEKERNEL
//!WIDTH HOOKED.w 4 /
//!HEIGHT HOOKED.h 4 /
//!COMPONENTS 1

#define SPATIAL_SIGMA (0.25 * float(HOOKED_size.y) / 1080.0) //Spatial window size, must be a positive real number.

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
		
		g = g + LINEKERNEL_texOff(vec2(di, 0.0)).x * gf;
		gn = gn + gf;
		
	}
	
	return g / gn;
}

vec4 hook() {
    return vec4(comp_gaussian_x(), 0.0, 0.0, 0.0);
}

//!DESC Godess2x-v3.2-Darken-DoG-(VeryFast)-Gaussian-Y
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINEKERNEL
//!SAVE LINEKERNEL
//!WIDTH HOOKED.w 4 /
//!HEIGHT HOOKED.h 4 /
//!COMPONENTS 1

#define SPATIAL_SIGMA (0.25 * float(HOOKED_size.y) / 1080.0) //Spatial window size, must be a positive real number.

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
		
		g = g + LINEKERNEL_texOff(vec2(0.0, di)).x * gf;
		gn = gn + gf;
		
	}
	
	return g / gn;
}

vec4 hook() {
    return vec4(comp_gaussian_y(), 0.0, 0.0, 0.0);
}


//!DESC Godess2x-v3.2-Darken-DoG-(VeryFast)-Upsample
//!HOOK MAIN
//!BIND HOOKED
//!BIND LINEKERNEL

#define STRENGTH 1.5 //Line darken proportional strength, higher is darker.

vec4 hook() {
	//This trick is only possible if the inverse Y->RGB matrix has 1 for every row... (which is the case for BT.709)
	//Otherwise we would need to convert RGB to YUV, modify Y then convert back to RGB.
    return HOOKED_tex(HOOKED_pos) + (LINEKERNEL_tex(HOOKED_pos).x * STRENGTH);
}

