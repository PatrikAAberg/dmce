#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
static void dmce_probe_body(unsigned int probenbr, int a, int b, int c, int d, int e);
#define DMCE_PROBE(p, a, b, c, d, e) (dmce_probe_body(p, a, b, c, d, e))
#endif
