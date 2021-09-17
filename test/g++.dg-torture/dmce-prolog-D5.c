/* Test prolog for code trace and data trace with 5 parameters */
#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
#include <stdint.h>
static void dmce_probe_body(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b, uint64_t dmce_param_c, uint64_t dmce_param_d, uint64_t dmce_param_e);
#define DMCE_PROBE(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e) (dmce_probe_body(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e))
#endif
