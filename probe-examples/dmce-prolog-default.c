#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
#ifdef __cplusplus
extern "C" { static void dmce_probe_body(unsigned int probenbr); }
#else
static void dmce_probe_body(unsigned int probenbr);
#endif
#define DMCE_PROBE(a) (dmce_probe_body(a))
#endif
