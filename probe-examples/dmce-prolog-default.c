#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
#ifdef __cplusplus
extern "C" { static void dmce_probe_body(unsigned int probenbr); }
#else
static void dmce_probe_body(unsigned int probenbr);
#endif
#define DMCE_PROBE(a) (dmce_probe_body(a))

/* Remove any GCC warnings caused by DMCE since some put warnings as errors */
#pragma GCC diagnostic ignored "-Wsequence-point" /* Better to get either lvalue or rvalue of de-reffed pointer with post-incr than nothing at all */

#if __GNUC__ >= 11
#pragma GCC diagnostic ignored "-Wmismatched-new-delete" /* GCC sometimes is more forgiving w/o comma notation */
#endif

#endif
