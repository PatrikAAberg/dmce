#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>
#define DMCE_MAX_HITS 10000
#define DMCE_TRACE_RINGBUFFER

#ifndef DMCE_PROBE_LOCK_DIR
#define DMCE_PROBE_LOCK_DIR "/tmp/dmce-trace-buffer-lock"
#endif

#ifndef DMCE_PROBE_OUTPUT_FILE_BIN
#define DMCE_PROBE_OUTPUT_FILE_BIN "/tmp/dmcebuffer.bin"
#endif

typedef struct {

    uint64_t timestamp;
    uint64_t probenbr;
    uint64_t vars[5];
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

    fp = fopen(DMCE_PROBE_OUTPUT_FILE_BIN, "w");
#ifdef DMCE_TRACE_RINGBUFFER
    unsigned int buf_pos = *dmce_probe_hitcount_p % DMCE_MAX_HITS;
    int i;

    for (i = 0; i < DMCE_MAX_HITS; i++) {

        unsigned int index = (buf_pos + i) % DMCE_MAX_HITS;
        fwrite(&dmce_buf_p[index], sizeof(dmce_probe_entry_t), 1, fp);
    }
#else
    fwrite(dmce_buf_p, sizeof(dmce_probe_entry_t), *dmce_probe_hitcount_p, fp);
#endif
    fclose(fp);
    remove("DMCE_PROBE_LOCK_DIR");
}

static void dmce_signal_handler(int sig) {

    /* Just call atexit and invoke the standard sig handler */
    dmce_atexit();
    signal(sig, SIG_DFL);
    kill(getpid(), sig);
}

#ifdef _GNU_SOURCE
#include <sched.h>
#else
int getcpu(unsigned int *cpu, unsigned int *node);
#endif
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
        if (! dmce_buffer_setup_done) {
            if (! (mkdir(DMCE_PROBE_LOCK_DIR,0))) {

                char s[32 * 3];
                dmce_buf_p = (dmce_probe_entry_t*)calloc( DMCE_MAX_HITS + 10,   /* room for race until we introduce a lock */
                                                          sizeof(dmce_probe_entry_t));

                dmce_trace_enabled_p = (int*)calloc(1, sizeof(int));
                dmce_probe_hitcount_p = (unsigned int*)calloc(1, sizeof(int));

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
                }

                /* Handler for normal exit */
                atexit(dmce_atexit);

                /* Just to avoid unused-function warnings */
                dmce_trace_disable();
                dmce_trace_enable();
            }
            else {
               /* Buffer already exist, wait for env var to be available and only init local pointers */
               while (NULL == (s_control_p  = getenv("dmce_trace_control")));
               sscanf(s_control_p, "%p %p %p", &dmce_trace_enabled_p, &dmce_buf_p, &dmce_probe_hitcount_p);
            }
            dmce_buffer_setup_done = 1;
        }
    }
#ifndef DMCE_TRACE_RINGBUFFER
    if (dmce_trace_is_enabled() && *dmce_probe_hitcount_p < DMCE_MAX_HITS) {
#else
    if (dmce_trace_is_enabled()) {
#endif
        unsigned int cpu;
        unsigned int index = __atomic_fetch_add (dmce_probe_hitcount_p, 1, __ATOMIC_SEQ_CST);
#ifdef DMCE_TRACE_RINGBUFFER
        index = index % DMCE_MAX_HITS;
#endif
        dmce_probe_entry_t* e_p = &dmce_buf_p[index];
        getcpu(&cpu, 0);
        e_p->timestamp = dmce_tsc();
        e_p->probenbr = dmce_probenbr;
        e_p->cpu = cpu;
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
    }
#ifndef DMCE_TRACE_RINGBUFFER
    else {
        dmce_trace_disable();
        /* Mark this trace buffer as full */
        dmce_buf_p[DMCE_MAX_HITS - 1].probenbr = 0xdeadbeef;
        dmce_buf_p[DMCE_MAX_HITS - 1].timestamp = dmce_tsc();
    }
#endif
}
#endif




/* end of file */
