/* Test prolog for code tracing only */
#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
static void dmce_probe_body(unsigned int probenbr);
#define DMCE_PROBE(a) (dmce_probe_body(a))
#endif
