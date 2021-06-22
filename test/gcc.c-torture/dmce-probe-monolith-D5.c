/* Test probe for code trace and data trace with 5 parameters */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

extern int dmce_probes[30000];

static void dmce_probe_body(unsigned int probenbr, int a, int b, int c, int d, int e)
{
  dmce_probes[probenbr] = 1;
}

#define DMCE_PROBE(a) (dmce_probe_body(p, a, b, c, d, e))
#endif //__DMCE_PROBE_FUNCTION_BODY__
