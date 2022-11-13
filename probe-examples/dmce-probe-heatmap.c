#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <string.h>
#include <sys/syscall.h>
#include <sys/sysinfo.h>

#ifdef DMCE_NBR_OF_PROBES
#define DMCE_NUM_PROBES DMCE_NBR_OF_PROBES
#else
#define DMCE_NUM_PROBES (100000*6)
#endif

#ifndef DMCE_PROBE_OUTPUT_PATH
#pragma GCC error "missing dmce configuration"
#endif

#define DMCE_PROBE_OUTPUT_FILE_BIN DMCE_PROBE_OUTPUT_PATH "/dmcebuffer.bin"


static uint64_t* dmce_buffer;
static uint64_t* dmce_tmp_buffer;
static int registered_at_exit = 0;

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

static void dmce_on_exit(int status, void* opaque) {

    FILE *fp;
    size_t n;
    int i;

    (void)opaque;

    if (!(fp = fopen(DMCE_PROBE_OUTPUT_FILE_BIN, "r"))) {

        fp = fopen(DMCE_PROBE_OUTPUT_FILE_BIN, "w");

        fwrite(dmce_tmp_buffer, sizeof(uint64_t), DMCE_NUM_PROBES, fp);
        fclose(fp);

        fp = fopen(DMCE_PROBE_OUTPUT_FILE_BIN, "r");
    }

    n = fread(dmce_tmp_buffer, sizeof(uint64_t), DMCE_NUM_PROBES, fp);
    if (n != DMCE_NUM_PROBES)
        fprintf(stderr, "DMCE: Something went terribly wrong...\n");

    for (i = 0; i < DMCE_NUM_PROBES; i++)
        dmce_tmp_buffer[i] += dmce_buffer[i];
    fclose(fp);

    fp = fopen(DMCE_PROBE_OUTPUT_FILE_BIN, "w");
    fwrite(dmce_tmp_buffer, sizeof(uint64_t), DMCE_NUM_PROBES, fp);
    fclose(fp);
    if (status > 150) {
        fprintf(stderr, "DMCE: terminated with signal %d (%s)\n", status - 150, strsignal(status - 150));

    }
}

static void dmce_signal_handler(int sig) {

    exit(150 + sig);
}

static void dmce_probe_body(unsigned int probenbr) {

    if (!registered_at_exit) {
        dmce_buffer = (uint64_t*)calloc(DMCE_NUM_PROBES, sizeof(uint64_t));
        dmce_tmp_buffer = (uint64_t*)calloc(DMCE_NUM_PROBES, sizeof(uint64_t));
        dmce_mkdir(DMCE_PROBE_OUTPUT_PATH);
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
        on_exit(dmce_on_exit, NULL);
        registered_at_exit = 1;
    }

    dmce_buffer[probenbr] ++;
}
#endif
