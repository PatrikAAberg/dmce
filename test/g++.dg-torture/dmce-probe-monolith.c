/* Test probe for code trace only */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

extern int dmce_probes[30000];

static void dmce_probe_body(unsigned int probenbr)
{
  dmce_probes[probenbr] = 1;
}

#define DMCE_PROBE(a) (dmce_probe_body(a))
#endif //__DMCE_PROBE_FUNCTION_BODY__
