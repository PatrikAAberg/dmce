#!/usr/bin/env bash

# This is a template for a bash script that takes
# as input on stdin  : A list of files to be examined (one per line, provided by DMCE)
# as output on stdout: < Same file as passed in > <Compile command line for the file>
# If no files provided, DMCE will revert to the default compile command in dmce.config
# Example below. Watch out! If you have a file named hello.c in your git this will be used!

echo "hello.c gcc -I/My/Include/path -DMY_SPECIAL_DEFINE hello.c"
