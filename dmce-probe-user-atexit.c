/* This is a simple template for a linux userspace probe using the printf on stderr  */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#define DMCE_NUM_PROBES 100000

static uint32_t dmce_buffer[DMCE_NUM_PROBES] = {0};
static uint32_t dmce_tmp_buffer[DMCE_NUM_PROBES] = {0};
static int registered_at_exit = 0;

static void dmce_atexit(void){

    FILE *fp;
    if (!(fp = fopen("/tmp/dmcebuffer.bin", "r"))) {

        fp = fopen("/tmp/dmcebuffer.bin", "w");
        fwrite(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES, fp);
        fclose(fp);

        fp = fopen("/tmp/dmcebuffer.bin", "r"); 
    }

    size_t n = fread(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES, fp);
    if (n != DMCE_NUM_PROBES)
        printf("DMCE: Something went terribly wrong...\n");

    for (int i = 0; i < DMCE_NUM_PROBES; i++)
        dmce_tmp_buffer[i] += dmce_buffer[i];
    fclose(fp);

    fp = fopen("/tmp/dmcebuffer.bin", "w");
    fwrite(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES, fp);
    fclose(fp);
}

static void dmce_probe_body(unsigned int probenbr) {

    if (!registered_at_exit) {

        atexit(dmce_atexit);
        registered_at_exit = 1;
    }

    dmce_buffer[probenbr] ++;
}
#endif //__DMCE_PROBE_FUNCTION_BODY__
