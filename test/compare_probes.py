#!/usr/bin/env python3

# Copyright (c) 2019 Ericsson AB
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

# ######
#
# Script to double check that the probes (i.e., the probe number) in
# <probe-references.log> and in <expr-references.log> the same ones.
#
# Idea:
#   - go through the both files
#   - compare:
#     * probe numbers
#     * file name
#     * line number
# #####

import sys
import re
import argparse
import time


# Print is expensive and can be disabled
do_print=1

time1 = time.time()

if (len(sys.argv) != 3):
    print("Usage: compare_probes <probe-references.log> <expr-references.log>")
    exit()

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    
# Read probe-references.log
probe_file = open(sys.argv[1]) 
probe_buf = probe_file.readlines()
probe_file.close()

# Read expr-references.log
expr_file = open(sys.argv[2]) 
expr_buf = expr_file.readlines()
expr_file.close()

# Function to call if the test failed
def test_failed(probe_nbr, error_msg):
    print(bcolors.FAIL)
    print("#"*12)
    print("Test failed!")
    print("Probe: " + str(probe_nbr) + " is wrong.")
    print(error_msg)
    print("#"*12)
    print(bcolors.ENDC)
    exit()


# Check if the files have the same number of entries
n_lines = len(probe_buf)
if (n_lines==len(expr_buf)):
    print("Both files have the same length: " + str(n_lines) + " lines")
else:
    print("The files does not have the same length.")


# Used for c expression recognition
exppatternlist = ['.*-CallExpr\sHexnumber\s<.*\,.*>.*',
                  '.*-CXXMemberCallExpr\sHexnumber\s<.*\,.*>.*',
                  '.*-ConditionalOperator\sHexnumber\s<.*\,.*>.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\*\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\/\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\-\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\+\'.*',
                  '.*UnaryOperator Hexnumber <.*\,.*>.*\'\+\+\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\&\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\|\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'=\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'<\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'>\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'==\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'!=\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\&\&\'.*',
                  '.*BinaryOperator Hexnumber <.*\,.*>.*\'\|\|\'.*',
                  '.*ReturnStmt Hexnumber <.*\,.*>.*']

re_exppatternlist = []

for exp in exppatternlist:
    re_exppatternlist.append(re.compile(exp))

# Iterate through the entries and compare probes
i = 0
while ( i<n_lines ):
    probe = probe_buf[i]
    expr = expr_buf[i]
    # print "-"*5
    # print "Probe: " + str(i)
    # print "probe file:"
    # print probe
    # print "expr file:"
    # print expr

    # split and retrieve the relevant parts of the lines
    # probe_line: <probe_nbr>:<c_file>:<line in c-file>
    probe_split = re.split(":", probe)
    probe_nbr =  int(probe_split[0])
    probe_file = probe_split[1]
    probe_line = int(probe_split[2])

    # Expre_line: <probe_nbr>:<c_file>:<line in c-file>:<expression_index>:<full Clang expression>
    expr_split = re.split(":", expr)
    expr_nbr = int(expr_split[0])
    expr_file = expr_split[1]
    expr_line = int(expr_split[2])
    expr_index = int(expr_split[3])
    expr_expr = expr_split[4]

    # Compare the probes
    if (probe_nbr != expr_nbr):
        error_msg = "Probe numbers are different. \n" +  "<probe-references.log>: " + str(probe_nbr) + "\n" + "<expr-references.log>:" + str(expr_nbr)
        test_failed(probe_nbr, error_msg)
    elif (probe_file != expr_file):
        error_msg = "File names are different.\n" + "<probe-references.log>: " + probe_file + "\n" + "<expr-references.log>:" + expr_file
        test_failed(probe_nbr, error_msg)
    elif (probe_line != expr_line):
        error_msg = "Line numbers are different.\n" + "<probe-references.log>: " + str(probe_line) + "\n" + "<expr-references.log>:" + str(expr_line)
        test_failed(probe_nbr, error_msg)

    # Check the expression index
    if (not re_exppatternlist[expr_index].match(expr_expr)):
        error_msg =  "Expression index was incorrect!"
        test_failed(probe_nbr, error_msg)

    i += 1

print(bcolors.OKGREEN + "All probes were correct!" + bcolors.ENDC)
