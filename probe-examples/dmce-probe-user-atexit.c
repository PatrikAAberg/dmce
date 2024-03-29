#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/stat.h>
#include <unistd.h>
#include <signal.h>
#include <string.h>

#ifdef DMCE_NBR_OF_PROBES
#define DMCE_NUM_PROBES DMCE_NBR_OF_PROBES
#else
#define DMCE_NUM_PROBES (100000*6)
#endif

#ifndef DMCE_PROBE_OUTPUT_PATH
#pragma GCC error "missing dmce configuration"
#endif

#define DMCE_PROBE_OUTPUT_FILE_BIN DMCE_PROBE_OUTPUT_PATH "/dmcebuffer.bin"


static uint32_t* dmce_buffer;
static uint32_t* dmce_tmp_buffer;
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

static void dmce_atexit(void){

    FILE *fp;
    size_t n;
    int i;

    if (!(fp = fopen(DMCE_PROBE_OUTPUT_FILE_BIN, "r"))) {

        fp = fopen(DMCE_PROBE_OUTPUT_FILE_BIN, "w");

        fwrite(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES, fp);
        fclose(fp);

        fp = fopen(DMCE_PROBE_OUTPUT_FILE_BIN, "r");
    }

    n = fread(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES, fp);
    if (n != DMCE_NUM_PROBES)
        printf("DMCE: Something went terribly wrong...\n");

    for (i = 0; i < DMCE_NUM_PROBES; i++)
        dmce_tmp_buffer[i] += dmce_buffer[i];
    fclose(fp);

    fp = fopen(DMCE_PROBE_OUTPUT_FILE_BIN, "w");
    fwrite(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES, fp);
    fclose(fp);
}

static void dmce_probe_body(unsigned int probenbr) {

    if (!registered_at_exit) {
        dmce_buffer = (uint32_t*)calloc(DMCE_NUM_PROBES, sizeof(uint32_t));
        dmce_tmp_buffer = (uint32_t*)calloc(DMCE_NUM_PROBES, sizeof(uint32_t));
        dmce_mkdir(DMCE_PROBE_OUTPUT_PATH);
        atexit(dmce_atexit);
        registered_at_exit = 1;
    }

    dmce_buffer[probenbr] ++;
}
#endif
