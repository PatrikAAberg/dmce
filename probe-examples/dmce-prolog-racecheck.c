#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
static void dmce_probe_body(unsigned int probenbr, unsigned int delay);
#define DMCE_PROBE(a,b) (dmce_probe_body(a,b))
#endif
