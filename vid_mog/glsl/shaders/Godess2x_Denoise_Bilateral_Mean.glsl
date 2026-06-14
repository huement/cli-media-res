//!DESC Godess2x-v3.2-Denoise-Bilateral-Mean
//!HOOK MAIN
//!BIND HOOKED

#define INTENSITY_SIGMA 0.1 //Intensity window size, higher is stronger denoise, must be a positive real number
#define SPATIAL_SIGMA 1.0 //Spatial window size, higher is stronger denoise, must be a positive real number.

#define INTENSITY_POWER_CURVE 1.0 //Intensity window power curve. Setting it to 0 will make the intensity window treat all intensities equally, while increasing it will make the window narrower in darker intensities and wider in brighter intensities.

#define KERNELSIZE (max(int(ceil(SPATIAL_SIGMA * 2.0)), 1) * 2 + 1) //Kernel size, must be an positive odd integer.
#define KERNELHALFSIZE (int(KERNELSIZE/2)) //Half of the kernel size without remainder. Must be equal to trunc(KERNELSIZE/2).
#define KERNELLEN (KERNELSIZE * KERNELSIZE) //Total area of kernel. Must be equal to KERNELSIZE * KERNELSIZE.

#define GETOFFSET(i) vec2((i % KERNELSIZE) - KERNELHALFSIZE, (i / KERNELSIZE) - KERNELHALFSIZE)

vec4 gaussian_vec(vec4 x, vec4 s, vec4 m) {
	vec4 scaled = (x - m) / s;
	return exp(-0.5 * scaled * scaled);
}

float gaussian(float x, float s, float m) {
	float scaled = (x - m) / s;
	return exp(-0.5 * scaled * scaled);
}

vec4 hook() {
	vec4 sum = vec4(0.0);
	vec4 n = vec4(0.0);
	
	vec4 vc = HOOKED_tex(HOOKED_pos);
	
	vec4 is = pow(vc + 0.0001, vec4(INTENSITY_POWER_CURVE)) * INTENSITY_SIGMA;
	float ss = SPATIAL_SIGMA;
	
	for (int i=0; i<KERNELLEN; i++) {
		vec2 ipos = GETOFFSET(i);
		vec4 v = HOOKED_texOff(ipos);
		vec4 d = gaussian_vec(v, is, vc) * gaussian(length(ipos), ss, 0.0);
		sum += d * v;
		n += d;
	}
	
	return sum / n;
}