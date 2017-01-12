/* This is a simple template for a linux userspace probe using the printf on stderr  */
/* This code is inserted at the top of all DMCE probed .c files!                     */

#include <stdio.h>

#define MAX_NUMBER_OF_PROBES 100000

static int dmce_probes[MAX_NUMBER_OF_PROBES] = {0};

static void dmce_probe_body(unsigned int probenbr)
{

  if (dmce_probes[probenbr] != 1)
  {
    dmce_probes[probenbr] = 1;
    fprintf(stderr, "\nDMCE_PROBE(%u)\n ",probenbr);
  }
}
