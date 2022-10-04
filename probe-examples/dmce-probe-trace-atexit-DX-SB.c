#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>
#include <fcntl.h>
#include <errno.h>
#include <sys/syscall.h>
#include <sys/sysinfo.h>

#ifndef DMCE_PROBE_NBR_TRACE_ENTRIES
#define DMCE_MAX_HITS 10000
#else
#define DMCE_MAX_HITS DMCE_PROBE_NBR_TRACE_ENTRIES
#endif

#define DMCE_TRACE_RINGBUFFER
#define NBR_STATUS_BITS 1

#ifndef DMCE_PROBE_LOCK_DIR_ENTRY
#pragma GCC error "missing dmce configuration"
#endif

#ifndef DMCE_PROBE_LOCK_DIR_EXIT
#pragma GCC error "missing dmce configuration"
#endif

#ifndef DMCE_PROBE_OUTPUT_PATH
#pragma GCC error "missing dmce configuration"
#endif

#define DMCE_PROBE_OUTPUT_FILE_BIN DMCE_PROBE_OUTPUT_PATH "/dmcebuffer.bin"

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

static int dmce_signal_core = 4242;
static int dmce_signo = 4242;

/* Recursive mkdir */
static void dmce_mkdir(char const* path) {
    char const* pos_path = path;

    char* dir = (char*)calloc(strlen(path) + 1, sizeof(char));
    char* pos_dir = dir;

    while (*pos_path != '\0') {
        if (*pos_path == '/') {
            mkdir(dir, S_IRWXU);
        }
        *pos_dir = *pos_path;
        pos_dir++;
        pos_path++;
    }

    mkdir(dir, S_IRWXU);
    free(dir);
}

static inline int dmce_num_cores() {

#ifdef DMCE_NUM_CORES
            return DMCE_NUM_CORES;
#else
            return get_nprocs();
#endif
}

static void dmce_dump_trace(int status) {

        int fp;
        char outfile[256];
        char infofile[256];
        int core;

        sprintf(outfile, "%s-%s.%d", DMCE_PROBE_OUTPUT_FILE_BIN, program_invocation_short_name, getpid());
        sprintf(infofile, "%s-%s.%d.info", DMCE_PROBE_OUTPUT_FILE_BIN, program_invocation_short_name, getpid());

        dmce_mkdir(DMCE_PROBE_OUTPUT_PATH);

        if ( -1 == (fp = open(outfile, O_CREAT | O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH))) {

            printf("DMCE trace: Error when opening trace file: %s\n", strerror(errno));
            return;
        }

        for (core = 0; core < dmce_num_cores(); core++) {

            unsigned int buf_pos = (dmce_probe_hitcount_p[core] >> NBR_STATUS_BITS) % DMCE_MAX_HITS;
            int i;
            dmce_probe_entry_t* e_p = &dmce_buf_p[core * DMCE_MAX_HITS];

            /* Only output to file if this core has been used at all */
            if (e_p->timestamp) {

                for (i = 0; i < DMCE_MAX_HITS; i++) {

                    unsigned int index = (buf_pos + i) % DMCE_MAX_HITS;
                    if ( -1 == write(fp, &dmce_buf_p[index + (DMCE_MAX_HITS * core)], sizeof(dmce_probe_entry_t) * 1)) {

                        printf("DMCE trace: Error when writing trace buffer to disk: %s\n", strerror(errno));
                        return;
                    }
                }
            }
        }
        close(fp);

        if ( -1 == (fp = open(infofile, O_CREAT | O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH))) {

            printf("DMCE trace: Error when opening info file: %s\n", strerror(errno));
            return;
        }

        {
            char info[80 * 10];
            char exit_info[80 * 3];

            if (dmce_signal_core == 4242) {

                sprintf(exit_info,  "Exit cause   : exit()\n"
                                    "Exit status  : %d\n"
                                    "System cores : %d\n", status, dmce_num_cores());
            }
            else {

                sprintf(exit_info, "Exit cause  : signal handler\n"
                                   "Core        : %d\n"
                                   "Signal      : %d (%s)\n"
                                   "System cores: %d\n", dmce_signal_core, dmce_signo, strsignal(dmce_signo), dmce_num_cores());
            }

            sprintf(info, "\nProbe     : dmce-probe-trace-atexit-DX-CB.c\n");
            strcat(info, exit_info);

            if ( -1 == write(fp, info, strlen(info))) {

                printf("DMCE trace: Error when writing info file to disk: %s\n", strerror(errno));
                return;
            }
        }

        close(fp);
        {
            char entrydirname[256];
            sprintf(entrydirname, "%s-%s.%d", DMCE_PROBE_LOCK_DIR_ENTRY, program_invocation_short_name, getpid());
            remove(entrydirname);
        }
}

static void dmce_on_exit(int status, void* opaque) {

    (void)opaque;

    /* Only do this once (exit dir needs to be removed at startup) */
    char exitdirname[256];
    sprintf(exitdirname, "%s-%s.%d", DMCE_PROBE_LOCK_DIR_EXIT, program_invocation_short_name, getpid());

    if (! (mkdir(exitdirname, 0))) {

        dmce_dump_trace(status);
    }
}

#ifdef _GNU_SOURCE
#include <sched.h>
#else
int sched_getcpu(void);
#endif

static void dmce_signal_handler(int sig) {

    char exitdirname[256];
    sprintf(exitdirname, "%s-%s.%ld", DMCE_PROBE_LOCK_DIR_EXIT, program_invocation_short_name, syscall(SYS_getpid));

    if (! (mkdir(exitdirname, 0))) {

        /* Make other threads stop */
        int i;

        for (i = 0; i < dmce_num_cores(); i++ )
            __atomic_fetch_add (&dmce_probe_hitcount_p[i], 1, __ATOMIC_RELAXED);

        /* Save current core and sig */
        dmce_signal_core = sched_getcpu();
        dmce_signo = sig;

        /* Dump trace and invoke the standard sig handler */

        dmce_dump_trace(0);

        signal(sig, SIG_DFL);
        kill(syscall(SYS_getpid), sig);
    }
    else {

        /* We should never get to this point, but if we do: */
        /* After 30 secs we have (hopefully) written the trace buffer, force an exit if we are still here */

        sleep(30);
        _Exit(1);
     }
}


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

        char entrydirname[256];
        sprintf(entrydirname, "%s-%s.%d", DMCE_PROBE_LOCK_DIR_ENTRY, program_invocation_short_name, getpid());

        if (! (mkdir(entrydirname, 0))) {

            /* This is the first thread executing a probe for ANY source file part of this process */

            /* allocate buffer, init env var and set up exit hook */
            /* env var format: dmce_enabled_p dmce_buf_p dmce_probe_hitcount_p*/

            char s[32 * 3];

            dmce_buf_p = (dmce_probe_entry_t*)calloc( dmce_num_cores() * (DMCE_MAX_HITS + 10), sizeof(dmce_probe_entry_t));

            dmce_trace_enabled_p = (int*)calloc(1, sizeof(int));
            dmce_probe_hitcount_p = (unsigned int*)calloc(dmce_num_cores(), sizeof(unsigned int));

            __atomic_store_n (&dmce_trace_enabled_p, dmce_trace_enabled_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_buf_p, dmce_buf_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_probe_hitcount_p, dmce_probe_hitcount_p, __ATOMIC_SEQ_CST);

            /* TODO: Inherited env ? */

            /*
            if (NULL != getenv("dmce_trace_control")) {

            }
            */

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

            on_exit(dmce_on_exit, NULL);

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
        unsigned int cpu = sched_getcpu();

//        unsigned int index = __atomic_fetch_add (dmce_probe_hitcount_p, 2, __ATOMIC_RELAXED);
//        unsigned int index = __atomic_fetch_add (&dmce_probe_hitcount_p[cpu], 2, __ATOMIC_RELAXED);
        unsigned int index = dmce_probe_hitcount_p[cpu];
        dmce_probe_hitcount_p[cpu] += 2;

        /* lowest bit means trace is stopped */
        if (index & 1)
            return 0;

#ifdef DMCE_TRACE_RINGBUFFER
        index = (index >> NBR_STATUS_BITS) % DMCE_MAX_HITS;
#endif
        dmce_probe_entry_t* e_p = &dmce_buf_p[index  + cpu * DMCE_MAX_HITS];
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
