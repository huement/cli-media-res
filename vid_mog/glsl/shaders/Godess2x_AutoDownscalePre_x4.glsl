//!DESC Godess2x-v3.2-AutoDownscalePre-x4
//!HOOK MAIN
//!BIND HOOKED
//!BIND NATIVE
//!WHEN OUTPUT.w NATIVE.w / 4.0 < OUTPUT.h NATIVE.h / 4.0 < * OUTPUT.w NATIVE.w / 2.4 > OUTPUT.h NATIVE.h / 2.4 > * *
//!WIDTH OUTPUT.w 2 /
//!HEIGHT OUTPUT.h 2 /

vec4 hook() {
	return HOOKED_tex(HOOKED_pos);
}
