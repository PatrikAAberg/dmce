/* This is a simple template for a DMCE probe in a statically linked monolitic system              */
/* NOTE! the array dmce_probes[] array must be defined somewhere in the build and zero-initalized! */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

extern int dmce_probes[5000];

static void dmce_probe_body(unsigned int probenbr)
{
  dmce_probes[probenbr] = 1;
}

#define DMCE_PROBE(a) (dmce_probe_body(a))
#endif
