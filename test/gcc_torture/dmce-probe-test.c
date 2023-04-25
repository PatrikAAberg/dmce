/* Test probe for no-variables case */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

static unsigned int dmce_dummy = 0;
static void dmce_probe_body(unsigned int probenbr)
{
  dmce_dummy = probenbr;
}

#define DMCE_PROBE(a) (dmce_probe_body(a))
#endif
