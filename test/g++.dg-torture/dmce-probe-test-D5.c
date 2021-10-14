/* Test probe for code trace and data trace with 5 parameters */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

static unsigned long dmce_dummy;

static void dmce_probe_body(unsigned long dmce_probenbr, unsigned long dmce_param_a, unsigned long dmce_param_b, unsigned long dmce_param_c, unsigned long dmce_param_d, unsigned long dmce_param_e)
{
  dmce_dummy = dmce_probenbr;
}

#define DMCE_PROBE(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e) (dmce_probe_body(dmce_probenbr, dmce_param_a, dmce_param_b, dmce_param_c, dmce_param_d, dmce_param_e))
#endif
