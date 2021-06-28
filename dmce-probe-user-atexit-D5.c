/* This is a simple template for a linux userspace probe using the printf on stderr  */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#define DMCE_NUM_PROBES 100000

static uint32_t dmce_buffer[DMCE_NUM_PROBES][6] = {0};
static uint32_t dmce_tmp_buffer[DMCE_NUM_PROBES][6] = {0};
static int registered_at_exit = 0;

static void dmce_atexit(void){

    FILE *fp;
    if (!(fp = fopen("/tmp/dmcebuffer.bin", "r"))) {

        fp = fopen("/tmp/dmcebuffer.bin", "w");
        fwrite(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES * 6, fp);
        fclose(fp);

        fp = fopen("/tmp/dmcebuffer.bin", "r"); 
    }

    size_t n = fread(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES * 6, fp);
    if (n != (DMCE_NUM_PROBES * 6))
        printf("DMCE: Something went terribly wrong...\n");

    for (int i = 0; i < DMCE_NUM_PROBES; i++)
        for (int j = 0; j < 6; j++)
            dmce_tmp_buffer[i][j] += dmce_buffer[i][j];
    fclose(fp);

    fp = fopen("/tmp/dmcebuffer.bin", "w");
    fwrite(dmce_tmp_buffer, sizeof(uint32_t), DMCE_NUM_PROBES * 6, fp);
    fclose(fp);
}

static void dmce_probe_body(unsigned int dmce_probenbr, int dmce_par_a, int dmce_par_b, int dmce_par_c, int dmce_par_d, int dmce_par_e) {

    if (!registered_at_exit) {

        atexit(dmce_atexit);
        registered_at_exit = 1;
    }

    dmce_buffer[dmce_probenbr][0] ++;
    dmce_buffer[dmce_probenbr][1] += dmce_par_a;
    dmce_buffer[dmce_probenbr][2] += dmce_par_b;
    dmce_buffer[dmce_probenbr][3] += dmce_par_c;
    dmce_buffer[dmce_probenbr][4] += dmce_par_d;
    dmce_buffer[dmce_probenbr][5] += dmce_par_e;
}
#endif //__DMCE_PROBE_FUNCTION_BODY__
