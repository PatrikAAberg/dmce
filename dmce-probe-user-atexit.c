/* This is a simple template for a linux userspace probe using the printf on stderr  */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#define DMCE_NUM_PROBES (100000*6)

static uint32_t* dmce_buffer;
static uint32_t* dmce_tmp_buffer;
static int registered_at_exit = 0;

static void dmce_atexit(void){

    FILE *fp;
    size_t n;
    int i;

    if (!(fp = fopen("/tmp/dmcebuffer.bin", "r"))) {

        fp = fopen("/tmp/dmcebuffer.bin", "w");
        fwrite(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES, fp);
        fclose(fp);

        fp = fopen("/tmp/dmcebuffer.bin", "r"); 
    }

    n = fread(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES, fp);
    if (n != DMCE_NUM_PROBES)
        printf("DMCE: Something went terribly wrong...\n");

    for (i = 0; i < DMCE_NUM_PROBES; i++)
        dmce_tmp_buffer[i] += dmce_buffer[i];
    fclose(fp);

    fp = fopen("/tmp/dmcebuffer.bin", "w");
    fwrite(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES, fp);
    fclose(fp);
}

static void dmce_probe_body(unsigned int probenbr) {

    if (!registered_at_exit) {
        dmce_buffer = (uint32_t*)calloc(DMCE_NUM_PROBES, sizeof(uint32_t));
        dmce_tmp_buffer = (uint32_t*)calloc(DMCE_NUM_PROBES, sizeof(uint32_t));
        atexit(dmce_atexit);
        registered_at_exit = 1;
    }

    dmce_buffer[probenbr] ++;
}
#endif
