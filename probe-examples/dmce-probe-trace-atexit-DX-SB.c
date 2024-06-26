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
#include <time.h>

#ifndef DMCE_PROBE_NBR_TRACE_ENTRIES
#define DMCE_MAX_HITS 10000
#else
#define DMCE_MAX_HITS DMCE_PROBE_NBR_TRACE_ENTRIES
#endif

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

#define DMCE_PNUM_HEXDUMP_HEADER        (1024 * 1024 * 1024)
#define DMCE_PNUM_HEXDUMP_PAYLOAD       (1024 * 1024 * 1024 + 1)
#define DMCE_PNUM_INITIAL_OVERHEAD      (1024 * 1024 * 1024 + 2)
#define DMCE_PNUM_PRINTF_HEADER         (1024 * 1024 * 1024 + 3)
#define DMCE_PNUM_PRINTF_PAYLOAD        (1024 * 1024 * 1024 + 4)

typedef struct {

    uint64_t timestamp;
    uint64_t probenbr;
    uint64_t cpu;
    uint64_t vars[DMCE_PROBE_NBR_OPTIONAL_ELEMENTS];
} dmce_probe_entry_t;

typedef struct {

    uint32_t value;
    uint32_t pad1;
    uint64_t pad2[7];
} dmce_buf_index_t;

typedef struct {

    uint64_t start_tsc;
    uint64_t end_tsc;
    struct timespec start_monotonic;
    struct timespec end_monotonic;
} dmce_time_info_t;

#ifdef _GNU_SOURCE
#include <sched.h>
#else
int sched_getcpu(void);
extern char *program_invocation_short_name;
#endif

#ifndef dmce_likely
#ifdef __GNUC__
#define dmce_likely(x)   __builtin_expect(!!(x), 1)
#define dmce_unlikely(x) __builtin_expect(!!(x), 0)
#else
#define dmce_likely(x)   (x)
#define dmce_unlikely(x) (x)
#endif
#endif

#ifdef __cplusplus
static dmce_probe_entry_t* dmce_buf_p = nullptr;
static dmce_buf_index_t* dmce_probe_hitcount_p = nullptr;
static dmce_time_info_t* dmce_time_info_p = nullptr;
#else
static dmce_probe_entry_t* dmce_buf_p = 0;
static dmce_buf_index_t* dmce_probe_hitcount_p = 0;
static dmce_time_info_t* dmce_time_info_p = 0;
#endif
static int dmce_buffer_setup_done = 0;

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

static int dmce_nproc_copy = 0;
static inline int dmce_num_cores(void);

static inline int dmce_num_cores(void) {

#ifdef DMCE_NUM_CORES
            return DMCE_NUM_CORES;
#else
            if (dmce_nproc_copy == 0)
                dmce_nproc_copy = get_nprocs();

            return dmce_nproc_copy;
#endif
}

static __inline__ uint64_t dmce_read_time_and_core(unsigned int* core_p) {

#if defined(__x86_64__)

        return __builtin_ia32_rdtscp(core_p);

#elif defined(__ARM_ARCH)

        uint64_t tcval;
        uint64_t core;

        /* Read time */
        asm volatile("mrs %0, cntvct_el0" : "=r" (tcval));

        /* Read core */
        *core_p = sched_getcpu();

        return tcval;

#else
#error Unsupported architecture: Timestamps cannot be retrieved
#endif
}

static void dmce_dump_trace(int status) {

        int fp;
        char outfile[256];
        char infofile[256];
        int core;
        int num_cores = dmce_num_cores();
        uint64_t newest_of_oldest = 0;

        sprintf(outfile, "%s-%s.%d", DMCE_PROBE_OUTPUT_FILE_BIN, program_invocation_short_name, getpid());
        sprintf(infofile, "%s-%s.%d.info", DMCE_PROBE_OUTPUT_FILE_BIN, program_invocation_short_name, getpid());

        dmce_mkdir(DMCE_PROBE_OUTPUT_PATH);

        if ( -1 == (fp = open(outfile, O_CREAT | O_WRONLY | O_TRUNC, S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH))) {

            printf("DMCE trace: Error when opening trace file: %s\n", strerror(errno));
            return;
        }

        for (core = 0; core < num_cores; core++) {

            int i;
            uint64_t oldest = UINT64_MAX;
            int buffer_full = 0;

            for (i = 0; i < DMCE_MAX_HITS; i++) {
                if ( dmce_buf_p[core * DMCE_MAX_HITS + i].timestamp < oldest)
                    oldest = dmce_buf_p[core * DMCE_MAX_HITS + i].timestamp;
            }

            buffer_full = (dmce_buf_p[core * DMCE_MAX_HITS + DMCE_MAX_HITS - 1].timestamp);

            if ((newest_of_oldest < oldest) && buffer_full)
                newest_of_oldest = oldest;
        }

        for (core = 0; core < num_cores; core++) {

            int i;

            for (i = 0; i < DMCE_MAX_HITS; i++) {

                /* Only output to file if this entry is above the limit */

                if (dmce_buf_p[i + (DMCE_MAX_HITS * core)].timestamp > newest_of_oldest) {

                    if ( -1 == write(fp, &dmce_buf_p[i + (DMCE_MAX_HITS * core)], sizeof(dmce_probe_entry_t) * 1)) {

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
            uint32_t cpu;
            char exit_info[80 * 4 + 256];
            char host[256];

            host[255] = '\0';
            gethostname(host, 255);

            if (dmce_signal_core == 4242) {

                sprintf(exit_info,  "Host         : %s\n"
                                    "Exit cause   : exit()\n"
                                    "Exit status  : %d\n"
                                    "System cores : %d\n", host, status, num_cores);
            }
            else {

                sprintf(exit_info,   "Host        : %s\n"
                                     "Exit cause  : signal handler\n"
                                     "Core        : %d\n"
                                     "Signal      : %d (%s)\n"
                                     "System cores: %d\n", host, dmce_signal_core, dmce_signo, strsignal(dmce_signo), num_cores);
            }

            clock_gettime(CLOCK_MONOTONIC, &(dmce_time_info_p->end_monotonic));
            dmce_time_info_p->end_tsc = dmce_read_time_and_core(&cpu);

            sprintf(info,   "Timestamp unit: Nanoseconds\n"
                            "Probe: dmce-probe-trace-atexit-DX-SB.c, te size: %zu\n"
                            "# trace-start-tsc: %lu\n"
                            "# trace-end-tsc: %lu\n"
                            "# trace-start-secs: %ld\n"
                            "# trace-end-secs: %ld\n"
                            "# trace-start-nsecs: %ld\n"
                            "# trace-end-nsecs: %ld\n",
                            sizeof(dmce_probe_entry_t),
                            dmce_time_info_p->start_tsc,
                            dmce_time_info_p->end_tsc,
                            dmce_time_info_p->start_monotonic.tv_sec,
                            dmce_time_info_p->end_monotonic.tv_sec,
                            dmce_time_info_p->start_monotonic.tv_nsec,
                            dmce_time_info_p->end_monotonic.tv_nsec);

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

        free(dmce_buf_p);
        free(dmce_trace_enabled_p);
        free(dmce_probe_hitcount_p);

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

static inline void dmce_stop_trace_threads(void) {

    int i;
    int dmce_n_cores = dmce_num_cores();

    for (i = 0; i < dmce_n_cores; i++ )
        __atomic_fetch_add (&dmce_probe_hitcount_p[i].value, 1, __ATOMIC_RELAXED);
}

static void dmce_signal_handler(int sig) {

    char exitdirname[256];

    /* If we come from a dmce breakpoint, we assume for now thread traces are already stopped, TODO: make this work properly with gdb */
    if (sig != SIGTRAP)
        dmce_stop_trace_threads();

    sprintf(exitdirname, "%s-%s.%ld", DMCE_PROBE_LOCK_DIR_EXIT, program_invocation_short_name, syscall(SYS_getpid));

    if (! (mkdir(exitdirname, 0))) {

        /* Save current core and sig */
        dmce_signal_core = sched_getcpu();
        dmce_signo = sig;

        /* Dump trace */

        dmce_dump_trace(0);

        signal(sig, SIG_DFL);
        kill(syscall(SYS_getpid), sig);
    }
    else {

        /* If we receive multiple signals (typically SIGINT while writing trace buffer): */
        /* After 2 minutes we have (hopefully) written the trace buffer, force an exit if we are still here */

        sleep(2 * 60);
        _Exit(128 + sig);
     }
}


static inline dmce_probe_entry_t* dmce_probe_body(unsigned int dmce_probenbr);

static inline __attribute__((unused)) void dmce_probe_body0(unsigned int dmce_probenbr) {

    dmce_probe_body(dmce_probenbr);
}

#if (DMCE_PROBE_NBR_OPTIONAL_ELEMENTS > 0) && (defined(__clang__)) || (!defined(__clang__))
static inline __attribute__((unused)) void dmce_probe_body1(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (dmce_likely(e_p)) {
        e_p->vars[0] = dmce_param_a;
    }
}
#endif

#if (DMCE_PROBE_NBR_OPTIONAL_ELEMENTS > 1) && (defined(__clang__)) || (!defined(__clang__))
static inline __attribute__((unused)) void dmce_probe_body2(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (dmce_likely(e_p)) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
    }
}
#endif

#if (DMCE_PROBE_NBR_OPTIONAL_ELEMENTS > 2) && (defined(__clang__)) || (!defined(__clang__))
static inline __attribute__((unused)) void dmce_probe_body3(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (dmce_likely(e_p)) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
    }
}
#endif

#if (DMCE_PROBE_NBR_OPTIONAL_ELEMENTS > 3) && (defined(__clang__)) || (!defined(__clang__))
static inline __attribute__((unused)) void dmce_probe_body4(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (dmce_likely(e_p)) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
    }
}
#endif

#if (DMCE_PROBE_NBR_OPTIONAL_ELEMENTS > 4) && (defined(__clang__)) || (!defined(__clang__))
static inline __attribute__((unused)) void dmce_probe_body5(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (dmce_likely(e_p)) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
    }
}
#endif

#if (DMCE_PROBE_NBR_OPTIONAL_ELEMENTS > 5) && (defined(__clang__)) || (!defined(__clang__))
static inline __attribute__((unused)) void dmce_probe_body6(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e,
                            uint64_t dmce_param_f) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (dmce_likely(e_p)) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
        e_p->vars[5] = dmce_param_f;
    }
}
#endif

#if (DMCE_PROBE_NBR_OPTIONAL_ELEMENTS > 6) && (defined(__clang__)) || (!defined(__clang__))
static inline __attribute__((unused)) void dmce_probe_body7(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e,
                            uint64_t dmce_param_f,
                            uint64_t dmce_param_g) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (dmce_likely(e_p)) {
        e_p->vars[0] = dmce_param_a;
        e_p->vars[1] = dmce_param_b;
        e_p->vars[2] = dmce_param_c;
        e_p->vars[3] = dmce_param_d;
        e_p->vars[4] = dmce_param_e;
        e_p->vars[5] = dmce_param_f;
        e_p->vars[6] = dmce_param_g;
    }
}
#endif

#if (DMCE_PROBE_NBR_OPTIONAL_ELEMENTS > 7) && (defined(__clang__)) || (!defined(__clang__))
static inline __attribute__((unused)) void dmce_probe_body8(unsigned int dmce_probenbr,
                            uint64_t dmce_param_a,
                            uint64_t dmce_param_b,
                            uint64_t dmce_param_c,
                            uint64_t dmce_param_d,
                            uint64_t dmce_param_e,
                            uint64_t dmce_param_f,
                            uint64_t dmce_param_g,
                            uint64_t dmce_param_h) {

    dmce_probe_entry_t* e_p = dmce_probe_body(dmce_probenbr);

    if (dmce_likely(e_p)) {
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
#endif

#if (DMCE_PROBE_NBR_OPTIONAL_ELEMENTS > 8) && (defined(__clang__)) || (!defined(__clang__))
static inline __attribute__((unused)) void dmce_probe_body9(unsigned int dmce_probenbr,
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
    if (dmce_likely(e_p)) {
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
#endif

#if (DMCE_PROBE_NBR_OPTIONAL_ELEMENTS > 9) && (defined(__clang__)) || (!defined(__clang__))
static inline __attribute__((unused)) void dmce_probe_body10(unsigned int dmce_probenbr,
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

    if (dmce_likely(e_p)) {
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
#endif

static inline dmce_probe_entry_t* dmce_probe_body(unsigned int dmce_probenbr) {

    /* The fast check followed by the thread safe check (this one can only go from 0 to 1 and never changes) */

    if (dmce_unlikely((!dmce_buffer_setup_done) || (!__atomic_load_n (&dmce_buffer_setup_done, __ATOMIC_SEQ_CST)))) {

        uint32_t cpu;
        uint64_t timestart;
        uint64_t timeend;
        unsigned int index;
        dmce_probe_entry_t* e_p;

        char entrydirname[256];
        sprintf(entrydirname, "%s-%s.%d", DMCE_PROBE_LOCK_DIR_ENTRY, program_invocation_short_name, getpid());

        timestart = dmce_read_time_and_core(&cpu);
        cpu = cpu & 0x0fff;

        if (dmce_unlikely(! (mkdir(entrydirname, 0)))) {

            /* This is the first thread executing a probe for ANY source file part of this process */

            /* allocate buffer, init env var and set up exit hook */
            /* env var format: dmce_enabled_p dmce_buf_p dmce_probe_hitcount_p dmce_time_info_p */

            char s[32 * 3];

            dmce_buf_p = (dmce_probe_entry_t*)aligned_alloc( 64, dmce_num_cores() * (DMCE_MAX_HITS + 10) * sizeof(dmce_probe_entry_t));
            memset(dmce_buf_p, 0, dmce_num_cores() * (DMCE_MAX_HITS + 10) * sizeof(dmce_probe_entry_t));

            dmce_trace_enabled_p = (int*)calloc(1, sizeof(int));

            dmce_probe_hitcount_p = (dmce_buf_index_t*)aligned_alloc(64, dmce_num_cores() * sizeof(dmce_buf_index_t));
            memset(dmce_probe_hitcount_p, 0, dmce_num_cores() * sizeof(dmce_buf_index_t));

            dmce_time_info_p = (dmce_time_info_t*)malloc(sizeof(dmce_time_info_t));

            clock_gettime(CLOCK_MONOTONIC, &(dmce_time_info_p->start_monotonic));
            dmce_time_info_p->start_tsc = timestart;

            __atomic_store_n (&dmce_trace_enabled_p, dmce_trace_enabled_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_buf_p, dmce_buf_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_probe_hitcount_p, dmce_probe_hitcount_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_time_info_p, dmce_time_info_p, __ATOMIC_SEQ_CST);

            /* TODO: Inherited env ? */

            /*
            if (NULL != getenv("dmce_trace_control")) {

            }
            */

            sprintf(s,
                    "%p %p %p %p",
                    (void*)dmce_trace_enabled_p,
                    (void*)dmce_buf_p,
                    (void*)dmce_probe_hitcount_p,
                    (void*)dmce_time_info_p);

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

            sscanf( s_control_p,
                    "%p %p %p %p",
                    (void**)&dmce_trace_enabled_p,
                    (void**)&dmce_buf_p,
                    (void**)&dmce_probe_hitcount_p,
                    (void**)&dmce_time_info_p);

            __atomic_store_n (&dmce_trace_enabled_p, dmce_trace_enabled_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_buf_p, dmce_buf_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_probe_hitcount_p, dmce_probe_hitcount_p, __ATOMIC_SEQ_CST);
            __atomic_store_n (&dmce_time_info_p, dmce_time_info_p, __ATOMIC_SEQ_CST);
        }
        __atomic_store_n (&dmce_buffer_setup_done, 1, __ATOMIC_SEQ_CST);

        timeend = dmce_read_time_and_core(&cpu);
        cpu = cpu & 0x0fff;

        /* Add two trace entries to reflect the time spent in init above */
        index = __atomic_fetch_add (&dmce_probe_hitcount_p[cpu].value, 2, __ATOMIC_RELAXED);
        index = (index >> NBR_STATUS_BITS) % DMCE_MAX_HITS;
        e_p = &dmce_buf_p[index  + cpu * DMCE_MAX_HITS];
        e_p->timestamp = timestart;
        e_p->probenbr = DMCE_PNUM_INITIAL_OVERHEAD;
        e_p->cpu = cpu;

        index = __atomic_fetch_add (&dmce_probe_hitcount_p[cpu].value, 2, __ATOMIC_RELAXED);
        index = (index >> NBR_STATUS_BITS) % DMCE_MAX_HITS;
        e_p = &dmce_buf_p[index  + cpu * DMCE_MAX_HITS];
        e_p->timestamp = timeend;
        e_p->probenbr = DMCE_PNUM_INITIAL_OVERHEAD;
        e_p->cpu = cpu;
     }

    if (dmce_likely(dmce_trace_is_enabled())) {

        uint32_t cpu;
        uint64_t time;
        unsigned int index;

        /* What core are we on, and what is the time? */
        time = dmce_read_time_and_core(&cpu);
        cpu = cpu & 0x0fff;

        /* The counter itself is protected by the core, but we cant stop tracing if we do not use atomics
        index = dmce_probe_hitcount_p[cpu];
        dmce_probe_hitcount_p[cpu] += 2;
        */

        index = __atomic_fetch_add (&dmce_probe_hitcount_p[cpu].value, 2, __ATOMIC_RELAXED);

        /* lowest bit means trace is stopped */
        if (index & 1) {
            return 0;
        }

        index = (index >> NBR_STATUS_BITS) % DMCE_MAX_HITS;

        dmce_probe_entry_t* e_p = &dmce_buf_p[index  + cpu * DMCE_MAX_HITS];
        e_p->timestamp = time;
        e_p->probenbr = dmce_probenbr;
        e_p->cpu = cpu;
        return e_p;
    }
    return 0;
}

static inline void dmce_hexdump(uint64_t hdnum, void* buf_p, uint64_t size) {

    if (dmce_likely(dmce_trace_is_enabled())) {

        uint32_t cpu;
        uint32_t dummy;
        uint64_t time;
        uint64_t oldtime;
        unsigned int index;
        unsigned int wrapped_index;
        int i;
        char* aritbuf_p = (char*)buf_p;

        /* 3 times 64 bit fragment header, 5 times 64 bit for data */
        int num_payload_entries = size / (5 * sizeof(uint64_t)) + 1;

        /* What core are we on, and what is the time? */
        time = dmce_read_time_and_core(&cpu);
        cpu = cpu & 0x0fff;

        /* The counter itself is protected by the core, but we cant stop tracing if we do not use atomics
        index = dmce_probe_hitcount_p[cpu];
        dmce_probe_hitcount_p[cpu] += 2;
        */

        index = __atomic_fetch_add (&dmce_probe_hitcount_p[cpu].value, 2 * (num_payload_entries + 1), __ATOMIC_RELAXED);

        /* lowest bit means trace is stopped */
        if (index & 1) {
            return;
        }

        index = index >> NBR_STATUS_BITS;
        wrapped_index = index % DMCE_MAX_HITS;

        dmce_probe_entry_t* e_p = &dmce_buf_p[wrapped_index  + cpu * DMCE_MAX_HITS];
        e_p->timestamp = time;
        e_p->probenbr = DMCE_PNUM_HEXDUMP_HEADER;
        e_p->vars[0] = size;
        e_p->vars[1] = num_payload_entries;
        e_p->cpu = cpu + ((uint64_t)hdnum << 32);
        index += 1;

        for (i = 0; i < num_payload_entries; i++) {

            /* Time is used as sequence number for payload entries on the same core, so we need to get unique values */
            oldtime = time;
            while (time == oldtime) {

                time = dmce_read_time_and_core(&dummy);
            }

            wrapped_index = (index + i) % DMCE_MAX_HITS;
            e_p = &dmce_buf_p[wrapped_index  + cpu * DMCE_MAX_HITS];

            e_p->timestamp = time;
            e_p->probenbr = DMCE_PNUM_HEXDUMP_PAYLOAD;
            e_p->cpu = cpu;

            if (size >= 5 * sizeof(uint64_t))
                /* Full entry */
                memcpy(&(e_p->vars[0]), aritbuf_p + (i * 5 * sizeof(uint64_t)), 5 * sizeof(uint64_t));
            else
                /* Tail */
                memcpy(&(e_p->vars[0]), aritbuf_p + (i * 5 * sizeof(uint64_t)), size);
            size -= 5 * sizeof(uint64_t);
        }
    }
}

#include <stdarg.h>

static void DMCE_PRINTF(const char* fmt, ...) {

    char printfbuf[1024];
    va_list args;
    int retsize;
    size_t size;

    va_start(args, fmt);
    retsize = vsnprintf (printfbuf, sizeof(printfbuf), fmt, args);
    va_end(args);

    if (retsize == -1) {

        sprintf(printfbuf, "Erronous format string");
        size = strlen(printfbuf);
    }
    else {

        size = (size_t)retsize;
        if (size > sizeof(printfbuf))
            size = sizeof(printfbuf);
    }

    if (dmce_likely(dmce_trace_is_enabled())) {

        uint32_t cpu;
        uint32_t dummy;
        uint64_t time;
        uint64_t oldtime;
        unsigned int index;
        unsigned int wrapped_index;
        int i;
        char* aritbuf_p = (char*)printfbuf;

        /* 3 times 64 bit fragment header, 5 times 64 bit for data */
        int num_payload_entries = size / (5 * sizeof(uint64_t)) + 1;

        /* What core are we on, and what is the time? */
        time = dmce_read_time_and_core(&cpu);
        cpu = cpu & 0x0fff;

        /* The counter itself is protected by the core, but we cant stop tracing if we do not use atomics
        index = dmce_probe_hitcount_p[cpu];
        dmce_probe_hitcount_p[cpu] += 2;
        */

        index = __atomic_fetch_add (&dmce_probe_hitcount_p[cpu].value, 2 * (num_payload_entries + 1), __ATOMIC_RELAXED);

        /* lowest bit means trace is stopped */
        if (index & 1) {
            return;
        }

        index = index >> NBR_STATUS_BITS;
        wrapped_index = index % DMCE_MAX_HITS;

        dmce_probe_entry_t* e_p = &dmce_buf_p[wrapped_index  + cpu * DMCE_MAX_HITS];
        e_p->timestamp = time;
        e_p->probenbr = DMCE_PNUM_PRINTF_HEADER;
        e_p->vars[0] = size;
        e_p->vars[1] = num_payload_entries;
        e_p->cpu = cpu;
        index += 1;

        for (i = 0; i < num_payload_entries; i++) {

            /* Time is used as sequence number for payload entries on the same core, so we need to get unique values */
            oldtime = time;
            while (time == oldtime) {

                time = dmce_read_time_and_core(&dummy);
            }

            wrapped_index = (index + i) % DMCE_MAX_HITS;
            e_p = &dmce_buf_p[wrapped_index  + cpu * DMCE_MAX_HITS];

            e_p->timestamp = time;
            e_p->probenbr = DMCE_PNUM_PRINTF_PAYLOAD;
            e_p->cpu = cpu;

            if (size >= 5 * sizeof(uint64_t))
                /* Full entry */
                memcpy(&(e_p->vars[0]), aritbuf_p + (i * 5 * sizeof(uint64_t)), 5 * sizeof(uint64_t));
            else
                /* Tail */
                memcpy(&(e_p->vars[0]), aritbuf_p + (i * 5 * sizeof(uint64_t)), size);
            size -= 5 * sizeof(uint64_t);
        }
    }
}

#include <signal.h>
static inline __attribute__((unused)) void dmce_breakpoint(void) {

    dmce_stop_trace_threads();
    raise(SIGTRAP);
}

#endif

/* end of file */
