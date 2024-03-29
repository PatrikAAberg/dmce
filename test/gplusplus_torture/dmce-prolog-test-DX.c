/* Test prolog for code trace and data trace with 5 parameters */
#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
#ifdef __cplusplus
static int* dmce_trace_enabled_p = nullptr;
#else
static int* dmce_trace_enabled_p = 0;
#endif
static inline int dmce_trace_is_enabled(void) { return *dmce_trace_enabled_p; }
static inline void dmce_trace_enable(void) { *dmce_trace_enabled_p = 1; }
static inline void dmce_trace_disable(void) { *dmce_trace_enabled_p = 0; }
typedef unsigned long dmce_uint64_t;
static void dmce_probe_body0(unsigned int dmce_probenbr);
static void dmce_probe_body1(unsigned int dmce_probenbr, dmce_uint64_t dmce_param_a);
static void dmce_probe_body2(unsigned int dmce_probenbr, dmce_uint64_t dmce_param_a, dmce_uint64_t dmce_param_b);
static void dmce_probe_body3(unsigned int dmce_probenbr, dmce_uint64_t dmce_param_a, dmce_uint64_t dmce_param_b, dmce_uint64_t dmce_param_c);
static void dmce_probe_body4(unsigned int dmce_probenbr, dmce_uint64_t dmce_param_a, dmce_uint64_t dmce_param_b, dmce_uint64_t dmce_param_c, dmce_uint64_t dmce_param_d);
static void dmce_probe_body5(unsigned int dmce_probenbr, dmce_uint64_t dmce_param_a, dmce_uint64_t dmce_param_b, dmce_uint64_t dmce_param_c, dmce_uint64_t dmce_param_d, dmce_uint64_t dmce_param_e);
static void dmce_probe_body6(unsigned int dmce_probenbr, dmce_uint64_t dmce_param_a, dmce_uint64_t dmce_param_b, dmce_uint64_t dmce_param_c, dmce_uint64_t dmce_param_d, dmce_uint64_t dmce_param_e, dmce_uint64_t dmce_param_f);
static void dmce_probe_body7(unsigned int dmce_probenbr, dmce_uint64_t dmce_param_a, dmce_uint64_t dmce_param_b, dmce_uint64_t dmce_param_c, dmce_uint64_t dmce_param_d, dmce_uint64_t dmce_param_e, dmce_uint64_t dmce_param_f, dmce_uint64_t dmce_param_g);
static void dmce_probe_body8(unsigned int dmce_probenbr, dmce_uint64_t dmce_param_a, dmce_uint64_t dmce_param_b, dmce_uint64_t dmce_param_c, dmce_uint64_t dmce_param_d, dmce_uint64_t dmce_param_e, dmce_uint64_t dmce_param_f, dmce_uint64_t dmce_param_g, dmce_uint64_t dmce_param_h);
static void dmce_probe_body9(unsigned int dmce_probenbr, dmce_uint64_t dmce_param_a, dmce_uint64_t dmce_param_b, dmce_uint64_t dmce_param_c, dmce_uint64_t dmce_param_d, dmce_uint64_t dmce_param_e, dmce_uint64_t dmce_param_f, dmce_uint64_t dmce_param_g, dmce_uint64_t dmce_param_h, dmce_uint64_t dmce_param_i);
static void dmce_probe_body10(unsigned int dmce_probenbr, dmce_uint64_t dmce_param_a, dmce_uint64_t dmce_param_b, dmce_uint64_t dmce_param_c, dmce_uint64_t dmce_param_d, dmce_uint64_t dmce_param_e, dmce_uint64_t dmce_param_f, dmce_uint64_t dmce_param_g, dmce_uint64_t dmce_param_h, dmce_uint64_t dmce_param_i, dmce_uint64_t dmce_param_j);
#define DMCE_PROBE0(dmce_probenbr) (dmce_probe_body0(dmce_probenbr))
#define DMCE_PROBE1(dmce_probenbr, dmce_param_a) (dmce_probe_body1(dmce_probenbr, dmce_param_a))
#define DMCE_PROBE2(dmce_probenbr, dmce_param_a, dmce_param_b) (dmce_probe_body2(dmce_probenbr, dmce_param_a, dmce_param_b))
#define DMCE_PROBE3(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c) (dmce_probe_body3(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c))
#define DMCE_PROBE4(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d) (dmce_probe_body4(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d))
#define DMCE_PROBE5(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e) (dmce_probe_body5(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e))
#define DMCE_PROBE6(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e, dmce_param_f) (dmce_probe_body6(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e, dmce_param_f))
#define DMCE_PROBE7(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e, dmce_param_f, dmce_param_g) (dmce_probe_body7(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e, dmce_param_f, dmce_param_g))
#define DMCE_PROBE8(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e, dmce_param_f, dmce_param_g, dmce_param_h) (dmce_probe_body8(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e, dmce_param_f, dmce_param_g, dmce_param_h))
#define DMCE_PROBE9(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e, dmce_param_f, dmce_param_g, dmce_param_h, dmce_param_i) (dmce_probe_body9(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e, dmce_param_f, dmce_param_g, dmce_param_h, dmce_param_i))
#define DMCE_PROBE10(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e, dmce_param_f, dmce_param_g, dmce_param_h, dmce_param_i, dmce_param_j) (dmce_probe_body10(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e, dmce_param_f, dmce_param_g, dmce_param_h, dmce_param_i, dmce_param_j))
#endif
/* 20 lines prolog makes counting line number easier to debug */
/**/
/**/
/**/
/**/
