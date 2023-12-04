#!/usr/bin/env python3

# Copyright (c) 2016 Ericsson AB
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import sys
import re

probes = []
executed_probes = []

print("Summary (PROBED:NBR:FILE:LINE)")

# Read all executed probes in log
total=0
with open(sys.argv[1]) as log:
    for line in log:
        total+=1
        m = re.match( r'.*DMCE_PROBE\((\d+)\).*', line, re.M|re.I)
        if m:
            executed_probes.append(m.group(1))

# Sort/remove doublets
executed_probes_sorted = sorted(set(executed_probes))

# Read probe list
probes_nbr=0
with open(sys.argv[2]) as probefile:
    for line in probefile:
        if len(line) > 1:
            m = re.match( r'(\d*):.*', line, re.M|re.I)
            if m:
                probes_nbr+=1
                if m.group(1) in executed_probes_sorted:
                     print("[YES] " + line.rstrip())
                else:
                     print("[NO ] " + line.rstrip())
            else:
                print("Probe reference file corrupt!")

exprobes_nbr = len(executed_probes_sorted)

print
print("Total probes executed: {}".format(len(executed_probes)))
print("Uniq probes executed: {}".format(len(executed_probes_sorted)))
print("Number of probes: {}".format(probes_nbr))
print
print("Test coverage: {:.1f} %".format(exprobes_nbr / float(probes_nbr) * 100))
