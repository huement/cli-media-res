//!DESC Godess2x-v4.0-AutoDownscalePre-x2
//!HOOK MAIN
//!BIND HOOKED
//!BIND NATIVE
//!WHEN OUTPUT.w NATIVE.w / 2.0 < OUTPUT.h NATIVE.h / 2.0 < * OUTPUT.w NATIVE.w / 1.2 > OUTPUT.h NATIVE.h / 1.2 > * *
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h

vec4 hook() {
	return HOOKED_tex(HOOKED_pos);
}
