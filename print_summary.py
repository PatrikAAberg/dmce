#!/usr/bin/env python

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

# Read test log
log = open(sys.argv[1])
logbuf = log.readlines()
log.close()

# Read probe list
probefile = open(sys.argv[2])
probesbuf = probefile.readlines()
probefile.close()

probes = []
executed_probes = []

# Read all executed probes
print "Summary (PROBED:NBR:FILE:LINE) "
index=0
total=len(logbuf)
while ( index < total ):
    m = re.match( r'.*DMCE_PROBE\((.*)\).*', logbuf[index], re.M|re.I)
    if (m):    
        executed_probes.insert(0, m.group(1))        
    index+=1 

# Sort/remove doublets
executed_probes_sorted = sorted(set(executed_probes))

# Read inserted probes
index=0
total=len(probesbuf)
while ( index < total ):
    m = re.match( r'(\d*):.*', probesbuf[index], re.M|re.I)
    if (m):
        if m.group(1) in executed_probes_sorted:
             print "[YES] " + probesbuf[index].rstrip()
        else:
             print "[NO ] " + probesbuf[index].rstrip()
    else: 
        print "Probe reference file corrupt!"
    index+=1

exprobes_nbr = len(executed_probes_sorted)
probes_nbr = len(probesbuf)

print
print "Total probes executed: {}".format(len(executed_probes))
print "Uniq probes executed: {}".format(len(executed_probes_sorted))
print "Number of probes: {}".format(probes_nbr)
print
print "Test coverage: {:.1f} %".format(exprobes_nbr / float(probes_nbr) * 100)
