/* This is a simple template for a linux userspace probe using the printf on stderr  */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#define DMCE_TRACE_SIZE (1000 + 10)
#define DMCE_MAX_HITS 1000

typedef struct {

    uint64_t timestamp;
    uint64_t probenbr;
} dmce_probe_entry_t;

static dmce_probe_entry_t* dmce_buf_p;
static int dmce_registered_at_exit = 0;
static int dmce_probe_hit_count = 0;

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

    /* Are we first? */
    if (!(fp = fopen("/tmp/dmcebuffer.bin", "r"))) {

        fp = fopen("/tmp/dmcebuffer.bin", "w");
        fclose(fp);
    }

    fp = fopen("/tmp/dmcebuffer.bin", "a");

    fwrite(dmce_buf_p, sizeof(dmce_probe_entry_t), dmce_probe_hit_count, fp);

    fclose(fp);
}

static void dmce_probe_body(unsigned int probenbr) {


    if (!dmce_registered_at_exit) {
        dmce_buf_p = (dmce_probe_entry_t*)calloc(DMCE_TRACE_SIZE, sizeof(dmce_probe_entry_t));
        atexit(dmce_atexit);
        dmce_registered_at_exit = 1;
    }

    if (dmce_probe_hit_count < DMCE_MAX_HITS) {

        dmce_probe_hit_count++;
        dmce_probe_entry_t* e_p = &dmce_buf_p[dmce_probe_hit_count - 1];
        e_p->timestamp = dmce_tsc();
        e_p->probenbr = probenbr;
    }
}
#endif




/* end of file */
