/* This is a simple template for a linux userspace probe using the printf on stderr  */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#define DMCE_MAX_HITS 1000

typedef struct {

    uint64_t timestamp;
    uint64_t probenbr;
    uint64_t vars[5];
} dmce_probe_entry_t;

#ifdef __cplusplus
static dmce_probe_entry_t* dmce_buf_p = nullptr;
static int* dmce_probe_hitcount_p = nullptr;
#else
static dmce_probe_entry_t* dmce_buf_p;
static int* dmce_probe_hitcount_p = 0;
#endif
static __inline__ uint64_t dmce_tsc(void) {

#if defined(__x86_64__)
    unsigned msw, lsw;
    __asm__ __volatile__ ("rdtsc": "=a"(lsw), "=d"(msw): : "memory");
    return ( (((uint64_t) msw) << 32) | ((uint64_t) lsw));
#else
#error Time stamp for this dmce probe only available on __x86_64__ arch!
#endif
}

static void dmce_atexit(void) {

    FILE *fp;

    fp = fopen("/tmp/dmcebuffer.bin", "w");

    fwrite(dmce_buf_p, sizeof(dmce_probe_entry_t), *dmce_probe_hitcount_p, fp);

    fclose(fp);
}

static void dmce_probe_body(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e) {

    /* Set up buffer and control if not done */

#ifdef __cplusplus
    if (dmce_trace_enabled_p == nullptr)
#else 
    if (dmce_trace_enabled_p == 0)
#endif
    {
        char* s_control_p;

        /* If first time: allocate buffer, init env var and set up exit hook */
        /* TODO: Make this less racy maybe, but only a prooblem if threads spawned before the first probe */
        /* env var format: enabled buf_p hitcount*/
        if(! (s_control_p = getenv("dmce_trace_control"))) {
        
            char s[32 * 3];

            dmce_buf_p = (dmce_probe_entry_t*)calloc( DMCE_MAX_HITS + 10,   /* room for race until we introduce a lock */
                                                      sizeof(dmce_probe_entry_t));
            
            dmce_trace_enabled_p = (int*)calloc(1, sizeof(int));
            dmce_probe_hitcount_p = (int*)calloc(1, sizeof(int));

            sprintf(s, "%p %p %p", dmce_trace_enabled_p, dmce_buf_p, dmce_probe_hitcount_p);
            setenv("dmce_trace_control", s, 0);

            atexit(dmce_atexit);

            /* Just to avoid unused-function warnings */
            dmce_trace_disable();
            dmce_trace_enable();
        }
        else {
            /* Buffer already exist, only init local pointers */
           s_control_p  = getenv("dmce_control_p");
           sscanf(s_control_p, "%p %p %p", &dmce_trace_enabled_p, &dmce_buf_p, &dmce_probe_hitcount_p);
        }

    }

    if (dmce_trace_is_enabled() && *dmce_probe_hitcount_p < DMCE_MAX_HITS) {

        (*dmce_probe_hitcount_p)++;
        dmce_probe_entry_t* e_p = &dmce_buf_p[(*dmce_probe_hitcount_p) - 1];
        e_p->timestamp = dmce_tsc();
        e_p->probenbr = dmce_probenbr;
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
    }
    else {
        dmce_trace_disable();
        /* Mark this trace buffer as full */
        dmce_buf_p[DMCE_MAX_HITS - 1].probenbr = 0xdeadbeef;
        dmce_buf_p[DMCE_MAX_HITS - 1].timestamp = dmce_tsc();
    }
}
#endif




/* end of file */
