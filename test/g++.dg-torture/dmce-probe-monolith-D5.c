/* Test probe for code trace and data trace with 5 parameters */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

extern int dmce_probes[30000];

static void dmce_probe_body(unsigned int dmce_probenbr, int dmce_param_a, int dmce_param_b, int dmce_param_c, int dmce_param_d, int dmce_param_e)
{
  dmce_probes[dmce_probenbr] = 1;
}

#define DMCE_PROBE(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e) (dmce_probe_body(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e))
#endif //__DMCE_PROBE_FUNCTION_BODY__
