#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>

#ifndef DMCE_PROBE_NBR_TRACE_ENTRIES
#define DMCE_MAX_HITS 10000
#else
#define DMCE_MAX_HITS DMCE_PROBE_NBR_TRACE_ENTRIES
#endif

#define DMCE_TRACE_RINGBUFFER
#define NBR_STATUS_BITS 1

#ifndef DMCE_PROBE_LOCK_DIR_ENTRY
#define DMCE_PROBE_LOCK_DIR_ENTRY "/tmp/dmce-trace-buffer-lock-entry"
#endif

#ifndef DMCE_PROBE_OUTPUT_FILE_BIN
#define DMCE_PROBE_OUTPUT_FILE_BIN "/tmp/dmcebuffer.bin"
#endif

typedef struct {

    uint64_t timestamp;
    uint64_t probenbr;
    uint64_t vars[DMCE_PROBE_NBR_OPTIONAL_ELEMENTS];
    uint64_t cpu;
} dmce_probe_entry_t;

#ifdef __cplusplus
static dmce_probe_entry_t* dmce_buf_p = nullptr;
static unsigned int* dmce_probe_hitcount_p = nullptr;
#else
static dmce_probe_entry_t* dmce_buf_p = 0;
static unsigned int* dmce_probe_hitcount_p = 0;
#endif
static int dmce_buffer_setup_done = 0;
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

#ifdef DMCE_TRACE_RINGBUFFER
    unsigned int buf_pos;
#endif

    /* Only do this once (exit dir needs to be removed at startup) */

    if (! (mkdir(DMCE_PROBE_LOCK_DIR_EXIT, 0))) {

        fp = fopen(DMCE_PROBE_OUTPUT_FILE_BIN, "w");

#ifdef DMCE_TRACE_RINGBUFFER

        buf_pos = (*dmce_probe_hitcount_p >> NBR_STATUS_BITS) % DMCE_MAX_HITS;
        int i;

        for (i = 0; i < DMCE_MAX_HITS; i++) {

            unsigned int index = (buf_pos + i) % DMCE_MAX_HITS;
            fwrite(&dmce_buf_p[index], sizeof(dmce_probe_entry_t), 1, fp);
        }
#else
        fwrite(dmce_buf_p, sizeof(dmce_probe_entry_t), *dmce_probe_hitcount_p, fp);
#endif
        fclose(fp);
        remove(DMCE_PROBE_LOCK_DIR_ENTRY);
    }
}

static void dmce_signal_handler(int sig) {

    /* Make other threads stop */
    __atomic_fetch_add (dmce_probe_hitcount_p, 1, __ATOMIC_RELAXED);

    /* Just call atexit and invoke the standard sig handler */
    dmce_atexit();
    signal(sig, SIG_DFL);
    kill(getpid(), sig);
}

#ifdef _GNU_SOURCE
#include <sched.h>
#else
int sched_getcpu(void);
#endif

static inline dmce_probe_entry_t* dmce_probe_body(unsigned int dmce_probenbr);

static inline void dmce_probe_body0(unsigned int dmce_probenbr) {

    dmce_probe_body(dmce_probenbr);
}

static inline void dmce_probe_body1(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (e_p) {
        e_p->vars[0] = dmce_param_a;
    }
}

static inline void dmce_probe_body2(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (e_p) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
    }
}

static inline void dmce_probe_body3(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (e_p) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
    }
}

static inline void dmce_probe_body4(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (e_p) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
    }
}

static inline void dmce_probe_body5(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (e_p) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
    }
}

static inline void dmce_probe_body6(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e,
                            uint64_t dmce_param_f) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (e_p) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
        e_p->vars[5] = dmce_param_f;
    }
}

static inline void dmce_probe_body7(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e,
                            uint64_t dmce_param_f,
                            uint64_t dmce_param_g) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (e_p) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
        e_p->vars[5] = dmce_param_f;
        e_p->vars[6] = dmce_param_g;
    }
}

static inline void dmce_probe_body8(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e,
                            uint64_t dmce_param_f,
                            uint64_t dmce_param_g,
                            uint64_t dmce_param_h) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (e_p) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
        e_p->vars[5] = dmce_param_f;
        e_p->vars[6] = dmce_param_g;
        e_p->vars[7] = dmce_param_h;
    }
}

static inline void dmce_probe_body9(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e,
                            uint64_t dmce_param_f,
                            uint64_t dmce_param_g,
                            uint64_t dmce_param_h,
                            uint64_t dmce_param_i) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);
    if (e_p) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
        e_p->vars[5] = dmce_param_f;
        e_p->vars[6] = dmce_param_g;
        e_p->vars[7] = dmce_param_h;
        e_p->vars[8] = dmce_param_i;
    }
}

static inline void dmce_probe_body10(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e,
                            uint64_t dmce_param_f,
                            uint64_t dmce_param_g,
                            uint64_t dmce_param_h,
                            uint64_t dmce_param_i,
                            uint64_t dmce_param_j) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (e_p) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
        e_p->vars[5] = dmce_param_f;
        e_p->vars[6] = dmce_param_g;
        e_p->vars[7] = dmce_param_h;
        e_p->vars[8] = dmce_param_i;
        e_p->vars[9] = dmce_param_j;
    }
}

static inline dmce_probe_entry_t* dmce_probe_body(unsigned int dmce_probenbr) {

    /* The fast check followed by the thread safe check (this one can only go from 0 to 1 and never changes) */

    if ((!dmce_buffer_setup_done) || (!__atomic_load_n (&dmce_buffer_setup_done, __ATOMIC_SEQ_CST))) {
        if (! (mkdir(DMCE_PROBE_LOCK_DIR_ENTRY, 0))) {

            /* This is the first thread executing a probe for ANY source file part of this process */

            /* remove any previous exit lock */

            remove(DMCE_PROBE_LOCK_DIR_EXIT);

            /* If first time: allocate buffer, init env var and set up exit hook */
            /* env var format: dmce_enabled_p dmce_buf_p dmce_probe_hitcount_p*/

            char s[32 * 3];

            dmce_buf_p = (dmce_probe_entry_t*)calloc( DMCE_MAX_HITS + 10, sizeof(dmce_probe_entry_t));

            dmce_trace_enabled_p = (int*)calloc(1, sizeof(int));
            dmce_probe_hitcount_p = (unsigned int*)calloc(1, sizeof(int));

            __atomic_store_n (&dmce_trace_enabled_p, dmce_trace_enabled_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_buf_p, dmce_buf_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_probe_hitcount_p, dmce_probe_hitcount_p, __ATOMIC_SEQ_CST);

            sprintf(s, "%p %p %p", dmce_trace_enabled_p, dmce_buf_p, dmce_probe_hitcount_p);
            setenv("dmce_trace_control", s, 0);

            /* Handler for smth-went-wrong signals */

            {
                struct sigaction sa;
                memset(&sa, 0, sizeof(sa));
                sa.sa_handler = dmce_signal_handler;
                sigaction(SIGBUS,   &sa, NULL);
                sigaction(SIGFPE,   &sa, NULL);
                sigaction(SIGILL,   &sa, NULL);
                sigaction(SIGINT,   &sa, NULL);
                sigaction(SIGKILL,  &sa, NULL);
                sigaction(SIGSEGV,  &sa, NULL);
                sigaction(SIGSYS,   &sa, NULL);
                sigaction(SIGTRAP,  &sa, NULL);
                sigaction(SIGABRT,  &sa, NULL);
            }

            /* Handler for normal exit */

            atexit(dmce_atexit);

            /* Enable trace at program entry? */

            dmce_trace_disable();
            if (DMCE_PROBE_TRACE_ENABLED)
                dmce_trace_enable();
        }
        else {

            /* Buffer already exist for this process, but local variables for this source file are not set.                  */
            /* Wait for trace control env var to be available and init local pointers for this source file with it contents. */

            char* s_control_p;

            /* Yield to make sure the mkdir can finish if ongoing, sched is non-favourable and cores are scarse */

            while (NULL == (s_control_p  = getenv("dmce_trace_control"))) usleep(10);
            sscanf(s_control_p, "%p %p %p", &dmce_trace_enabled_p, &dmce_buf_p, &dmce_probe_hitcount_p);
            __atomic_store_n (&dmce_trace_enabled_p, dmce_trace_enabled_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_buf_p, dmce_buf_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_probe_hitcount_p, dmce_probe_hitcount_p, __ATOMIC_SEQ_CST);
        }
        __atomic_store_n (&dmce_buffer_setup_done, 1, __ATOMIC_SEQ_CST);
    }

#ifndef DMCE_TRACE_RINGBUFFER
    if (dmce_trace_is_enabled() && *dmce_probe_hitcount_p < DMCE_MAX_HITS) {
#else
    if (dmce_trace_is_enabled()) {
#endif
        unsigned int cpu;
        unsigned int index = __atomic_fetch_add (dmce_probe_hitcount_p, 2, __ATOMIC_RELAXED);

        /* lowest bit means trace is stopped */
        if (index & 1)
            return 0;

#ifdef DMCE_TRACE_RINGBUFFER
        index = (index >> NBR_STATUS_BITS) % DMCE_MAX_HITS;
#endif
        dmce_probe_entry_t* e_p = &dmce_buf_p[index];
        cpu = sched_getcpu();
        e_p->timestamp = dmce_tsc();
        e_p->probenbr = dmce_probenbr;
        e_p->cpu = cpu;
        return e_p;
    }
#ifndef DMCE_TRACE_RINGBUFFER
    else {
        dmce_trace_disable();

        /* Mark this trace buffer as full */

        dmce_buf_p[DMCE_MAX_HITS - 1].probenbr = 0xdeadbeef;
        dmce_buf_p[DMCE_MAX_HITS - 1].timestamp = dmce_tsc();
    }
#endif
    return 0;
}
#endif

/* end of file */
