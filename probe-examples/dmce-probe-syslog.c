/* This is a simple template for a Linux userspace syslog probe  */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

#include <syslog.h>

#define MAX_NUMBER_OF_PROBES 100000

static int dmce_probes[MAX_NUMBER_OF_PROBES] = {0};

static void dmce_probe_body(unsigned int probenbr)
{
  if (dmce_probes[probenbr] != 1)
  {
    dmce_probes[probenbr] = 1;
    syslog(LOG_INFO, "\nDMCE_PROBE(%u)\n ",probenbr);
  }
}
#endif
