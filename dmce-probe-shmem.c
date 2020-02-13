/* This is a template for a linux userspace probe using shared memory  */

#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

#include <stdio.h>
#include <sys/mman.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdint.h>

#define DMCE_NUMBER_OF_PROBES (80000)
#define DMCE_BUFFER_SIZE ((( (DMCE_NUMBER_OF_PROBES * sizeof(uint32_t) /4096) ) * 4096) + 4096)
#define NUM_BUFFERS (1)

//#define DMCE_DEBUG

static const char* dmce_probe_buffer_name[] = {

        "/dmce_buffer0"
    };

static int dmce_probe_buffer_fd[NUM_BUFFERS];

void* restrict dmce_probe_buffer_p[NUM_BUFFERS];
volatile int dmce_probe_buffers_ready;

#ifdef DMCE_DEBUG
static FILE* dmce_l_fd;
#endif

#define DMCE_BUFFER_CREATED     (0)
#define DMCE_BUFFER_EXIST       (1)
#define DMCE_TRUNCATE_FAILED    (2)
#define DMCE_MMAP_FAILED        (3)
#define DMCE_SHM_OPEN_FAILED    (4)
#define DMCE_BUFFER_READY       (5)

static int dmce_create_or_just_map_buffers(int create) {

    int i;

    for (i=0; i < NUM_BUFFERS; i++) {

        if (create) {
             if ((dmce_probe_buffer_fd[i] = shm_open(dmce_probe_buffer_name[i],
                                                     O_RDWR | O_CREAT | O_EXCL,
                                                     S_IRUSR | S_IWUSR)) == -1)
                 return DMCE_BUFFER_EXIST;

             if ((ftruncate(dmce_probe_buffer_fd[i], DMCE_BUFFER_SIZE) == -1))
                 return DMCE_TRUNCATE_FAILED;
        }
        else {

            if (dmce_probe_buffers_ready)
                return DMCE_BUFFER_READY;

/*TODO: Remove this race cond*/

            if ((dmce_probe_buffer_fd[i] = shm_open(dmce_probe_buffer_name[i],
                                                     O_RDWR,
                                                     S_IRUSR | S_IWUSR)) == -1)
                 return DMCE_SHM_OPEN_FAILED;
        }

        if ( (dmce_probe_buffer_p[i] = mmap(NULL,
                                            DMCE_BUFFER_SIZE,
                                            PROT_WRITE,
                                            MAP_SHARED,
                                            dmce_probe_buffer_fd[i], 0)) == MAP_FAILED)
            return DMCE_MMAP_FAILED;
    }

    dmce_probe_buffers_ready = 1;

    return DMCE_BUFFER_READY;
}

static void dmce_probe_body(unsigned int probenbr) {

#ifdef DMCE_DEBUG
    dmce_l_fd = fopen("/tmp/git_probing.log","a");
    fprintf(dmce_l_fd,"\nProbe %d entry!\n", probenbr );
    fclose(dmce_l_fd);
#endif

    if (!dmce_probe_buffers_ready) {

        int ret;

        if ((ret = dmce_create_or_just_map_buffers(1)) != DMCE_BUFFER_READY) {


            if (ret != DMCE_BUFFER_EXIST) {
#ifdef DMCE_DEBUG
                dmce_l_fd = fopen("/tmp/git_probing.log","a");
                fprintf(dmce_l_fd,"ERROR: dmce_create_buffers() returned %d\n", ret );
                fclose(dmce_l_fd);
#endif
            }
            else
               dmce_create_or_just_map_buffers(0);
        }

#ifdef DMCE_DEBUG
            dmce_l_fd = fopen("/tmp/git_probing.log","a");
            fprintf(dmce_l_fd,"Waiting for dmce_probe_buffers_ready\n" );
            fclose(dmce_l_fd);
#endif

        while (!dmce_probe_buffers_ready);
    }

#ifdef DMCE_DEBUG
            dmce_l_fd = fopen("/tmp/git_probing.log","a");
            fprintf(dmce_l_fd,"Buffers should be ready, increasing probe value\n" );
            fclose(dmce_l_fd);
#endif
    uint32_t* restrict probe_p = (uint32_t*) dmce_probe_buffer_p[0];
    probe_p[probenbr] += 1;

}
#endif //__DMCE_PROBE_FUNCTION_BODY__
