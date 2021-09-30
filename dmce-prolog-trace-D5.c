/* Test prolog for code trace and data trace with 5 parameters */
#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
#include <stdint.h>
#ifdef __cplusplus
static int* dmce_trace_enabled_p = nullptr;
#else
static int* dmce_trace_enabled_p = 0;
#endif
static inline int dmce_trace_is_enabled() { return *dmce_trace_enabled_p; }
static inline void dmce_trace_enable(void) { *dmce_trace_enabled_p = 1; }
static inline void dmce_trace_disable(void) { *dmce_trace_enabled_p = 0; }
static void dmce_probe_body(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b, uint64_t dmce_param_c, uint64_t dmce_param_d, uint64_t dmce_param_e);
#define DMCE_PROBE(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e) (dmce_probe_body(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e))
#endif
/* 20 lines probe makes counting line number easier to debug */
/**/
/**/
/**/
/**/
/**/
/**/
/**/
/**/
