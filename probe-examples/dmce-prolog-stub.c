#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
static int __attribute__((unused)) dmce_probe_body(unsigned int probenbr);

#define DMCE_PROBE(a) (dmce_probe_body(a))
#endif
