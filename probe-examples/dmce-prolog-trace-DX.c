/* Test prolog for code trace and data trace with 5 parameters */
#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
#ifdef __cplusplus
static int* dmce_trace_enabled_p = nullptr;
#else
static int* dmce_trace_enabled_p = 0;
#endif
static inline int dmce_trace_is_enabled(void) { return *dmce_trace_enabled_p; }
static inline void dmce_trace_enable(void) { __atomic_store_n (dmce_trace_enabled_p, 1, __ATOMIC_SEQ_CST); }
static inline void dmce_trace_disable(void) { __atomic_store_n (dmce_trace_enabled_p, 0, __ATOMIC_SEQ_CST); }
typedef unsigned long uint64_t;
static inline __attribute__((unused)) void dmce_probe_body0(unsigned int dmce_probenbr);
static inline __attribute__((unused)) void dmce_probe_body1(unsigned int dmce_probenbr, uint64_t dmce_param_a);
static inline __attribute__((unused)) void dmce_probe_body2(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b);
static inline __attribute__((unused)) void dmce_probe_body3(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b, uint64_t dmce_param_c);
static inline __attribute__((unused)) void dmce_probe_body4(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b, uint64_t dmce_param_c, uint64_t dmce_param_d);
static inline __attribute__((unused)) void dmce_probe_body5(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b, uint64_t dmce_param_c, uint64_t dmce_param_d, uint64_t dmce_param_e);
static inline __attribute__((unused)) void dmce_probe_body6(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b, uint64_t dmce_param_c, uint64_t dmce_param_d, uint64_t dmce_param_e, uint64_t dmce_param_f);
static inline __attribute__((unused)) void dmce_probe_body7(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b, uint64_t dmce_param_c, uint64_t dmce_param_d, uint64_t dmce_param_e, uint64_t dmce_param_f, uint64_t dmce_param_g);
static inline __attribute__((unused)) void dmce_probe_body8(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b, uint64_t dmce_param_c, uint64_t dmce_param_d, uint64_t dmce_param_e, uint64_t dmce_param_f, uint64_t dmce_param_g, uint64_t dmce_param_h);
static inline __attribute__((unused)) void dmce_probe_body9(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b, uint64_t dmce_param_c, uint64_t dmce_param_d, uint64_t dmce_param_e, uint64_t dmce_param_f, uint64_t dmce_param_g, uint64_t dmce_param_h, uint64_t dmce_param_i);
static inline __attribute__((unused)) void dmce_probe_body10(unsigned int dmce_probenbr, uint64_t dmce_param_a, uint64_t dmce_param_b, uint64_t dmce_param_c, uint64_t dmce_param_d, uint64_t dmce_param_e, uint64_t dmce_param_f, uint64_t dmce_param_g, uint64_t dmce_param_h, uint64_t dmce_param_i, uint64_t dmce_param_j);
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

#define DMCE_PROBE DMCE_PROBE0

/* Remove any GCC warnings caused by DMCE since some put warnings as errors */
#pragma GCC diagnostic ignored "-Wsequence-point" /* Better to get either lvalue or rvalue of de-reffed pointer with post-incr than nothing at all */

#ifdef __cplusplus
#if __GNUC__ >= 11
#pragma GCC diagnostic ignored "-Wmismatched-new-delete" /* GCC sometimes is more forgiving w/o comma notation */
#endif
#endif
#endif
