/* This is a simple template for a linux userspace probe using the printf on stderr  */
#ifndef __DMCE_PROBE_FUNCTION_BODY__
#define __DMCE_PROBE_FUNCTION_BODY__

#include <stdio.h>

static void dmce_probe_body(unsigned int probenbr)
{
    fprintf(stderr, "\nDMCE_PROBE(%u)\n ",probenbr);
}
#endif
