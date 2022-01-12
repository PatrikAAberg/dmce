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

import os
import sys
import re
import argparse
import time

# Print is expensive and can be disabled
do_print=1

parsed_file = sys.argv[1]

# Get number of data variables
ndvs = os.getenv('DMCE_NUM_DATA_VARS')
if ndvs == None:
    numDataVars = 0
else:
    numDataVars = int(ndvs)

# variable type specified?
tvtype = os.getenv('DMCE_TRACE_VAR_TYPE')
if tvtype is None:
    tvtype="uint64_t"

# Get path to config files
configpath = os.getenv('DMCE_CONFIG_PATH')

time1 = time.time()

if (len(sys.argv) != 5):
    print("Usage: gen-probefile <inputfile.c> <outputfile.c.probed> <probedata.dmce> <expression.dmce>")
    exit()

# Read constructs exclude file
cxl = open(configpath + "/constructs.exclude")
cxl_buf = cxl.readlines()
cxl.close()

# Create list of functions to include
finc=[]
dmceinclude = open(configpath + "/dmce.include")
finclines = dmceinclude.readlines()
dmceinclude.close()
for func in finclines:
    funcpos = func.find(':')
    if (funcpos != -1):
        # In correct file?
        re_incfile = re.compile(".*" + func[:funcpos-1] + ".*")
        if re_incfile.match(parsed_file):
            finc.append(func[funcpos+1:].rstrip())

if len(finc) == 0:
    finc.append(".*")
    in_function_scope = True
else:
    in_function_scope = False

re_func_inc_list = []
for func in finc:
    re_func_inc_list.append(re.compile(".*-FunctionDecl.* (" + func + ") \'"))
    re_func_inc_list.append(re.compile(".*-CXXMethodDecl.* (" + func + ") \'"))
    re_func_inc_list.append(re.compile(".*-CXXConstructorDecl.* (" + func + ") \'"))
    re_func_inc_list.append(re.compile(".*-CXXDestructorDecl.* (" + func + ") \'"))

# Create list of functions to exclude
fexcl=[]
dmceexclude = open(configpath + "/dmce.exclude")
fexcllines = dmceexclude.readlines()
dmceexclude.close()
for func in fexcllines:
    funcpos = func.find(':')
    if (funcpos != -1):
        # In correct file?
        re_incfile = re.compile(".*" + func[:funcpos-1] + ".*")
        if re_incfile.match(parsed_file):
            fexcl.append(func[funcpos+1:].rstrip())

re_func_excl_list = []
for func in fexcl:
    re_func_excl_list.append(re.compile(".*-CXXMethodDecl.*" + func + ".*"))
    re_func_excl_list.append(re.compile(".*-FunctionDecl.*" + func + ".*"))
    re_func_excl_list.append(re.compile(".*-CXXConstructorDecl.*" + func + ".*"))
    re_func_excl_list.append(re.compile(".*-CXXDestructorDecl.*" + func + ".*"))

if len(re_func_excl_list) == 0:
    re_func_excl_list.append(re.compile("do_not_exclude_any_functions"))

# Make regexps for constructs exclusion
re_cxl_list = []
for construct in cxl_buf:
    re_cxl_list.append(re.compile(".*" + construct.rstrip() + ".*"))
    if do_print:
        print(".*{}.*".format(construct.rstrip()))

if do_print:
    print("constructs exclude list: {}".format(len(re_cxl_list)))
    print("Number of variables to trace: " + str(numDataVars))


parsed_file_exp = parsed_file
probe_prolog = "(DMCE_PROBE(TBD),"
probe_epilog = ")"

current_function = ""
expdb_exptext = []
expdb_linestart = []
expdb_colstart = []
expdb_lineend = []
expdb_colend = []
expdb_elineend = []
expdb_ecolend = []
expdb_in_c_file= []
expdb_tab = []
expdb_exppatternmode = []
expdb_secstackvars = []
expdb_func = []
expdb_index = 0

secStackPos = []
secStackVars = []

def printSecStackVars():
    i=0
    print("SECSTACKVARS:")
    while (i < expdb_index):
        print("INDEX: " + str(i))
        print(expdb_secstackvars[i])
        i+=1

cur_lend = 0
cur_cend = 0
cur_tab = 0

lskip = 0
cskip = 0
skip_scope = 0
skip_scope_tab  = 0
in_parmdecl = 0
in_parmdecl_tab  = 0
skip_backtrail = 0
skip_backtrail_tab = 0
skip_lvalue = 0
skip_lvalue_tab = 0

function_scope_tab = 0

lineindex = 0

inside_expression = 0
in_parsed_file = 0

probed_lines = []

trailing = 0

lstart = "0"
lend = "0"
cstart = "0"
cend = "0"
scopelstart = "0"
scopecstart = "0"
skiplend = "0"
skipcend = "0"

last_lstart = "0"
last_cstart = "0"

probes = 0

# Read clang AST diff from stdin
rawlinebuf = sys.stdin.readlines()
linebuf=[]
rawlinestotal = len(rawlinebuf)

if do_print:
    print("Generating DMCE probes")

# Look for general info and pre-filter out stuff
c_plusplus = 0
for line in rawlinebuf:
    # c++ file?
    if "CXX" in line:
        c_plusplus=1

    # Make built-in functions look like lib functions
    line = re.sub("<built\-in>", "dmce_built_in.h", line)
    # Make scratch space look like include file ref
    line = re.sub("<scratch space>", "dmce_scratch_space.h", line)
    # Remove all "nice info" pointing to include files
    line = re.sub("\(.* at .*\)", "", line)
    linebuf.append(line)

linestotal=rawlinestotal

# Regexps for C/C++ expression recognition
if configpath != None and os.path.isfile(configpath + '/recognizedexpressions.py'):
    sys.path.insert(1, configpath)
    import recognizedexpressions
    exppatternlist = recognizedexpressions.exppatternlist
    exppatternmode = recognizedexpressions.exppatternmode
else:
    exppatternlist = ['.*-CallExpr\sHexnumber\s<.*\,.*>.*',
                      '.*-CXXMemberCallExpr\sHexnumber\s<.*\,.*>.*',
                      '.*-StaticAssertDecl\sHexnumber\s<.*\,.*>.*',
                      '.*-ConditionalOperator\sHexnumber\s<.*\,.*>.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'\*\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'\/\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'\-\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'\+\'.*',
                      '.*UnaryOperator Hexnumber <.*\,.*>.*\'\+\+\'.*',
                      '.*UnaryOperator Hexnumber <.*\,.*>.*\'\-\-\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'\&\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'\|\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'=\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'<\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'>\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'==\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'!=\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'>=\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'<=\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'\&\&\'.*',
                      '.*BinaryOperator Hexnumber <.*\,.*>.*\'\|\|\'.*',
                      '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\+\=\'.*',
                      '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\-\=\'.*',
                      '.*ReturnStmt Hexnumber <.*\,.*>.*']

    # Modes:
    #  1    Contained space, use as is
    #  2    Free, need to look for next
    #  x    Free, look for next at colpos + x
    exppatternmode = [1,1,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,6]

re_exppatternlist = []

for exp in exppatternlist:
    re_exppatternlist.append(re.compile(exp))

# Used to extract expression type and operator type
exp_pat = re.compile('.*-(.*)\sHexnumber\s<.*\d>(.*)')

# Escape some characters
parsed_file_exp = re.sub("\/", "\/", parsed_file_exp)
parsed_file_exp = re.sub("\.", "\.", parsed_file_exp)
parsed_file_exp = re.sub("\-", "\-", parsed_file_exp)
parsed_file_exp = re.sub("\+", "\+", parsed_file_exp)

cf = open(parsed_file)
pbuf = cf.readlines()

cf_len = len(pbuf)

if do_print:
    print("!!!" + parsed_file + "!!!")

# Regexps for file refs, trailing and states

re_compile_skip_pos         = re.compile(r'.*<.*\.h:(\d*):(\d*)\,\s.*\.c:(\d*):(\d*)>.*')

re_file_ref_anypos            = re.compile(r'.*<(.*\.c|.*\.cpp|.*\.h|.*\.hh):\d*:\d*.*')
re_file_ref_middle          = re.compile(r'.*\, (.*\.c|.*\.cpp|.*\.h|.*\.hh):.*>.*')
re_file_ref_right           = re.compile(r'.*<.*> (.*\.c|.*\.cpp|.*\.h|.*\.hh):.*')
re_compound                 = re.compile(r'.*CompoundStmt.*')

re_parsed_file_statement    = re.compile(r'.*<line:\d*:\d*,\sline:\d*:\d*>.*')
re_update_pos_A             = re.compile(r'.*<line:(\d*):(\d*)\,\sline:(\d*):(\d*)>.*')
re_update_pos_B             = re.compile(r'.*<line:(\d*):(\d*)\,\scol:(\d*)>.*')
re_update_pos_C             = re.compile(r'.*<col:(\d*)>.*')
re_update_pos_D             = re.compile(r'.*<col:(\d*)\,\sline:(\d*):(\d*)>.*')
re_update_pos_E             = re.compile(r'.*<col:(\d*)\,\scol:(\d*)>.*')
re_update_pos_F             = re.compile(r'.*<line:(\d*):(\d*)>.*')
re_update_pos_H             = re.compile(r'.*, line:(\d*):(\d*)>.*')
re_update_pos_J             = re.compile(r'.*, line:(\d*):(\d*)>\sline:(\d*):(\d*)\s.*')
re_update_pos_G             = re.compile(r'.*<line:(\d*):(\d*)\,\sline:(\d*):(\d*)>\sline:(\d*):(\d*)\s.*')
re_update_pos_I             = re.compile(r'.*<col:(\d*),\sline:(\d*):(\d*)>\sline:(\d*):(\d*)\s.*')
re_update_scope_end         = re.compile(r'.*\, line:(\d*):(\d*)>.*')
re_parsed_file            = re.compile(".*\,\s" + parsed_file_exp + ".*")
re_lvalue                   = re.compile(".*lvalue.*")

# Used in probe insertion pass for regrets
re_regret_insertion         = re.compile(".*case.*DMCE.*:.*|.*return.*\{.*")

# Regexps below skips (not_to_skip overrides skip) entire blocks
re_sections_to_not_skip = []
re_sections_to_not_skip.append(re.compile(r'.*CXXRecordDecl Hexnumber.*referenced class.*'))
re_sections_to_not_skip.append(re.compile(r'.*CXXRecordDecl Hexnumber.*class.*definition.*'))

# The ones to skip
re_sections_to_skip = []
re_sections_to_skip.append(re.compile(r'.*-VarDecl Hexnumber.*'))
re_sections_to_skip.append(re.compile(r'.*-InitListExpr.*'))
re_sections_to_skip.append(re.compile(r'.*RecordDecl Hexnumber.*'))
re_sections_to_skip.append(re.compile(r'.*-EnumDecl Hexnumber.*'))
re_sections_to_skip.append(re.compile(r'.*constexpr.*'))
re_sections_to_skip.append(re.compile(r'.*-TemplateArgument expr.*'))
re_sections_to_skip.append(re.compile(r'.*-StaticAssertDecl.*'))

# Parameter and variable declarations
re_sections_parmdecl = []
re_sections_parmdecl.append(re.compile(r'.*-ParmVarDecl Hexnumber.*'))

# Variable stack barriers
re_var_barriers = []
re_var_barriers.append(re.compile(r'.*-CXXRecordDecl.*'))

# Variable and param var declarations
re_parmdeclarations = []
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'size_t\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'size_t\':\'unsigned long\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'long\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'unsigned long\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'int\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'unsigned int\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'.* \*\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'size_t\':\'unsigned long\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'size_t\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'long\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'unsigned long\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'int\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'unsigned int\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'.* \*\'.*'))

# scopes to skip
re_skip_scopes = []
re_skip_scopes.append(re.compile(r'.*-DeclStmt Hexnumber.*'))


# Populate c expression database
while (lineindex < linestotal):
    if do_print:
        print("---------------------")
        print("Pre-filtered AST line:           " + linebuf[lineindex])
    if '<<<NULL>>>' in linebuf[lineindex] or '<<invalid sloc>>' in linebuf[lineindex]:
        lineindex+=1
        continue

    # Addition according to diff file?
    if linebuf[lineindex].startswith("+"):
        is_addition=1
    else:
        is_addition=0

    # Check what tab we are on
    tabtmp = linebuf[lineindex].find("|-")
    if (tabtmp != -1):
        tab = tabtmp

    #Compensate for + if added line in diff
    if (is_addition):
        tab-=1

    if (skip_backtrail and (tab <= skip_backtrail_tab)):
        skip_backtrail=0
    if (skip_lvalue and (tab <= skip_lvalue_tab)):
        skip_lvalue=0
    if (skip_scope and (tab <= skip_scope_tab)):
        skip_scope=0
    if (in_parmdecl and (tab <= in_parmdecl_tab)):
        in_parmdecl=0
    if (in_function_scope) and (tab <= function_scope_tab):
        in_function_scope = False

    # file refs
    anypos = re_file_ref_anypos.match(linebuf[lineindex])
    middle = re_file_ref_middle.match(linebuf[lineindex])
    right = re_file_ref_right.match(linebuf[lineindex])

    # Compound statement
    compound = re_compound.match(linebuf[lineindex])

    anyposself = False
    middleself = False
    rightself = False
    rightother = False
    middleother = False
    anyposother = False

    if anypos:
        anyposself = (parsed_file in anypos.group(1))
        if not anyposself:
            anyposother = True
    if middle:
        middleself = (parsed_file in middle.group(1))
        if not middleself:
            middleother = True
    if right:
        rightself = (parsed_file in right.group(1))
        if not rightself:
            rightother = True

#    print("anypos: " + str(anypos))
#    print("right: " + str(right))
#    print("middle: " + str(middle))
#    print("anyposself: " + str(anyposself))
#    print("rightself: " + str(rightself))
#    print("middleself: " + str(middleself))
#    print("anyposother: " + str(anyposotherother))
#    print("rightother: " + str(rightother))
#    print("middleother: " + str(middleother))

    # Do not probe lvalues for c, but do for c++
    found_lvalue = re_lvalue.match(linebuf[lineindex])
    if (found_lvalue and not c_plusplus):
        skip_lvalue = 1
        skip_lvalue_tab = tab

    # If we start in a .h file and end in a c-file, skip!
    get_skip_pos = re_compile_skip_pos.match(linebuf[lineindex])
    if (get_skip_pos):
        lskip_temp = int(get_skip_pos.group(3))
        cskip_temp = int(get_skip_pos.group(4))
        if (lskip_temp > lskip):
            lskip=lskip_temp
            cskip=cskip_temp
        if ((lskip_temp == lskip) and (cskip_temp > cskip)):
            cskip=cskip_temp


    # Replace filename with 'line' for further parsing
    linebuf[lineindex] = re.sub(parsed_file_exp, "line", linebuf[lineindex])

    # Check if we are leaving (entering is checked after expression search)
    if (rightother) or (middleother and not rightself) or (anyposother and not rightself and not middleself):
        in_parsed_file = 0
        trailing=0
        if numDataVars > 0:
            if not skip_scope:
                skip_scope = 1
                skip_scope_tab = tab

    # Special: For this one we get full position info, so we can set the flag before check for expressions
    if anyposself and not (middle or right):
        in_parsed_file = 1

    # A compound expression always gives us a new scope
    if compound and skip_scope and in_parsed_file:
        skip_scope = 0

    # The different ways of updating position:
    #
    # A <line:62:3, line:161:3>
    # B <line:26:3, col:17>
    # C <col:17>
    # D <col:54, line:166:1>
    # E <col:5, col:58>
    # F <line:26:3>
    # G <line:97:5, line:101:5> line:98:15\s

    backtrailing = 0
    exp_extra = 0
    col_position_updated=0
    line_position_updated=0

    # Sort in order of common apperance
    # MATCH G
    # MATCH C
    # MATCH E
    # MATCH B
    # MATCH F
    # MATCH A
    # MATCH D

    # I
    exp_pos_update = re_update_pos_I.match(linebuf[lineindex])
    if exp_pos_update:
        col_position_updated = 1
        exp_extra = 1
        lend = exp_pos_update.group(4)
        cstart = exp_pos_update.group(1)
        cend = exp_pos_update.group(5)
        skiplend = exp_pos_update.group(2)
        skipcend = exp_pos_update.group(3)

        if int(lstart) > int(lend):
            scopelstart = lstart
            scopecstart = cstart
        else:
            scopelstart = lend
            scopecstart = cend

        if (in_parsed_file):
            trailing=1

        if do_print == 2:
            print("MATCH I: Start: ("+ lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())

    # G
    exp_pos_update = re_update_pos_G.match(linebuf[lineindex])
    if exp_pos_update:
        line_position_updated=1
        col_position_updated = 1
        exp_extra = 1
        if in_parsed_file:
            lstart = exp_pos_update.group(1)
            cstart = exp_pos_update.group(2)
        else:
            lstart = exp_pos_update.group(5)
            cstart = exp_pos_update.group(6)

        lend = exp_pos_update.group(5)
        cend = exp_pos_update.group(6)
        skiplend = exp_pos_update.group(3)
        skipcend = exp_pos_update.group(4)

        if int(lstart) > int(lend):
            scopelstart = lstart
            scopecstart = cstart
        else:
            scopelstart = lend
            scopecstart = cend

        if (in_parsed_file):
            trailing=1

        if do_print == 2:
            print("MATCH G: Start: ("+ lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())


    # C
    exp_pos_update = re_update_pos_C.match(linebuf[lineindex])
    if exp_pos_update:
        col_position_updated=1
        cstart = exp_pos_update.group(1)
        scopecstart = cstart
        cend = cstart
        skipcend = cend
        if do_print == 2:
            print("MATCH C: Start: ("+ lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())

    # E
    if not col_position_updated:
        exp_pos_update = re_update_pos_E.match(linebuf[lineindex])
        if exp_pos_update:
            col_position_updated=1
            exp_extra = 1
            cstart = exp_pos_update.group(1)
            scopecstart = cstart
            cend = exp_pos_update.group(2)
            skipcend = cend
            if do_print == 2:
                print("MATCH E: Start: (" + lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())

    # B
    exp_pos_update = re_update_pos_B.match(linebuf[lineindex])
    if exp_pos_update:
        line_position_updated=1
        col_position_updated = 1
        exp_extra = 1
        lstart = exp_pos_update.group(1)
        lend = lstart
        cstart = exp_pos_update.group(2)
        scopelstart = lstart
        scopecstart = cstart
        cend = exp_pos_update.group(3)
        skipcend = cend
        skiplend = lend
        if (in_parsed_file):
            trailing=1

        if do_print == 2:
            print("MATCH B: Start: ("+ lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())

    # F
    if not line_position_updated:
        exp_pos_update = re_update_pos_F.match(linebuf[lineindex])
        if exp_pos_update:
            line_position_updated=1
            col_position_updated = 1
            lstart = exp_pos_update.group(1)
            cstart = exp_pos_update.group(2)
            scopelstart = lstart
            scopecstart = cstart
            lend=lstart
            cend=cstart
            skiplend = lend
            skipcend = cend
            if (in_parsed_file):
                trailing=1

            if do_print == 2:
                print("MATCH F: Start: (" + lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())

    # A
    if not line_position_updated:
        exp_pos_update = re_update_pos_A.match(linebuf[lineindex])
        if exp_pos_update:
            line_position_updated=1
            col_position_updated = 1
            exp_extra = 1
            lstart = exp_pos_update.group(1)
            lend = exp_pos_update.group(3)
            cstart = exp_pos_update.group(2)
            cend = exp_pos_update.group(4)
            skiplend = lend
            skipcend = cend
            if (in_parsed_file):
                trailing=1
                scopelstart = lstart
                scopecstart = cstart

            if do_print == 2:
                print("MATCH A: Start: ("+ lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())

    # D
    if not col_position_updated:
        exp_pos_update = re_update_pos_D.match(linebuf[lineindex])
        if exp_pos_update:
            col_position_updated=1
            exp_extra = 1
            lend = exp_pos_update.group(2)
            cstart = exp_pos_update.group(1)
            scopecstart = cstart
            cend = exp_pos_update.group(3)
            skiplend = lend
            skipcend = cend
            if do_print == 2:
                print("MATCH D: Start: (" + lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())

    # J
    if not line_position_updated:
        exp_pos_update = re_update_pos_J.match(linebuf[lineindex])
        if exp_pos_update:
            line_position_updated=1
            col_position_updated = 1
            lend = exp_pos_update.group(1)
            cend = exp_pos_update.group(2)
            skiplend = lend
            skipcend = cend
            lstart = exp_pos_update.group(3)
            lend = exp_pos_update.group(4)
            scopelstart = lstart
            scopelend = lend
            if (in_parsed_file):
                trailing=1

            if do_print == 2:
                print("MATCH J: Start: (" + lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())

    # H
    if not line_position_updated:
        exp_pos_update = re_update_pos_H.match(linebuf[lineindex])
        if exp_pos_update:
            line_position_updated=1
            col_position_updated = 1
            lend = exp_pos_update.group(1)
            cend = exp_pos_update.group(2)
            skiplend = lend
            skipcend = cend
            if (in_parsed_file):
                trailing=1

            if do_print == 2:
                print("MATCH H: Start: (" + lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())

    # Only for updating scope end if we get back to self, filename is filtered eariler!
    exp_pos_update = re_update_scope_end.match(linebuf[lineindex])
    if exp_pos_update:
        skiplend = exp_pos_update.group(1)
        skipcend = exp_pos_update.group(2)
        if do_print == 2:
            print("MATCH UPDATE_SCOPE_END: Start: (" + lstart + ", " + cstart + ") End: (" + lend + ", " + cend + ") ->" + linebuf[lineindex].rstrip())



    # Check if backtrailing within current expression
    if (int(lstart) > int(lend)):
        backtrailing = 1

    # Check if global backtrailing. Note! Within the parsed c file!
    if ( in_parsed_file and (( int(last_lstart) > int(lstart))  or ( ( int(last_lstart) == int(lstart) ) and (int(last_cstart) > int(cstart)))) ):
        backtrailing = 1

        # Check if this backtrailing is a compound or similar, in that case skip the whole thing
        # CompoundStmt Hexnumber <line:104:44, line:107:15>
        found_parsed_file_statement = re_parsed_file_statement.match(linebuf[lineindex])
        if (found_parsed_file_statement):
            skip_backtrail = 1
            skip_backtrail_tab = tab

    # Check for sections to skip

    found_section_to_skip=0
    for section in re_sections_to_skip:
        m = section.match(linebuf[lineindex])
        mnot = False
        for not_section in re_sections_to_not_skip:
            if not_section.match(linebuf[lineindex]):
                mnot = True
        if (m and not mnot):
            found_section_to_skip=1

    if (found_section_to_skip and in_parsed_file):
        lskip_temp = int(skiplend)
        cskip_temp = int(skipcend)
        if (lskip_temp > lskip):
            lskip=lskip_temp
            cskip=cskip_temp
        if ((lskip_temp == lskip) and (cskip_temp > cskip)):
            cskip=cskip_temp

    # Set skip flag
    if (int(lstart) > lskip):
        skip = 0
    else:
        skip = 1

    if ( int(lstart) == lskip):
        if (int(cstart) > cskip):
            skip=0
        else:
            skip=1

    # Check if in for section to not insert variables
    found_section_parmdecl = 0
    for section in re_sections_parmdecl:
        m = section.match(linebuf[lineindex])
        if m:
            found_section_parmdecl = True

    if found_section_parmdecl and not in_parmdecl:
        in_parmdecl = 1
        in_parmdecl_tab = tab

    # Check if entering function scope
    if not in_function_scope:
        for re_f in re_func_inc_list:
            f_m = re_f.match(linebuf[lineindex])
            if f_m:
                current_function = f_m.group(1)
                in_function_scope = True
                function_scope_tab = tab

    # Get a copy of linebuf[lineindex] without argument list to only search func names
    argsstripped = re.sub('\'.*\'','',linebuf[lineindex])

    # Check if exit function scope
    if in_function_scope:
        for re_f in re_func_excl_list:
            if re_f.match(argsstripped):
                in_function_scope = False

    print("Parsed file: " + parsed_file)
    print("Parsed AST line:                     " + linebuf[lineindex])
    print("Position => " + "start: " + lstart + ", " + cstart + "  end: " + lend + ", " + cend + "  skip (end): " + skiplend + ", " + skipcend + "  scope (start): " + scopelstart + ", " + scopecstart + "  exp (end): " + str(cur_lend) + ", " + str(cur_cend))
    print("Flags => " + " in parsed file: " + str(in_parsed_file) +  " skip: " + str(skip) + " trailing: " + str(trailing) + " backtrailing: " + str(backtrailing) + " inside expression: " + str(inside_expression) + " skip scope: " + str(skip_scope) + "in parmdecl: " + str(in_parmdecl) + " sct: " + str(skip_scope_tab) + " infuncscope: " + str(in_function_scope))

    # ...and this is above. Check if found (almost) the end of an expression and update in that case
    if inside_expression:
        print("Inside expresson wating to pass l: " + str(cur_lend) + "   c: " + str(cur_cend))
        # If we reached the last subexpression in the expression or next expression or statement
        if ( (int(scopelstart) > cur_lend) or ( (int(scopelstart) == cur_lend) and (int(scopecstart) > cur_cend) ) ):
            expdb_lineend.append(int(lstart))
            expdb_colend.append(int(cstart) -1 )
            expdb_tab.append(tab)
            expdb_func.append(current_function)
            if not in_parmdecl:
                expdb_secstackvars.append(secStackVars.copy())
            else:
                expdb_secstackvars.append([])

            expdb_index +=1
            if do_print:
                print("FOUND END/NEXT (" + linebuf[lineindex].rstrip() + ")  FOR  (" + linebuf[inside_expression].rstrip() + ")")
            inside_expression = 0
#            cur_lend = 0
#            cur_cend = 0

    # Special case: We can always pop the stack as far as possible at function entries
    at_func_entry = False
    if "-FunctionDecl" in linebuf[lineindex]:
        at_func_entry = True

    # pop section stack?
    if ((in_parsed_file or at_func_entry) and not inside_expression and numDataVars > 0):
        while True:
            if len(secStackPos) > 0:
                l, c = secStackPos[len(secStackPos) - 1]
                if (int(scopelstart) > l) or ((int(scopelstart) == l) and (int(scopecstart) > c)):
                    secStackPos.pop()
                    secStackVars.pop()
                else:
                    break
            else:
                break
    print("Scope stack after pop check: ")
    print(secStackPos)
    print(secStackVars)

    if ((exp_extra) and (trailing) and (is_addition) and (not backtrailing) and (not inside_expression) and (not skip) and (not skip_backtrail) and (not skip_lvalue) and (in_function_scope)):
        i = 0
        while (i < len(re_exppatternlist)):
            re_exp = re_exppatternlist[i]
            if (re_exp.match(linebuf[lineindex])):
               if do_print:
                   print("FOUND EXP: start: (" + lstart.rstrip() + "," + cstart.rstrip() + ")" + linebuf[lineindex].rstrip())

               # Sanity check
               if (int(lstart) > int(cf_len)):
                 raise ValueError('{} sanity check failed! lstart: {} cf_len {}'.format(parsed_file, lstart, cf_len))

               # Self contained expression
               if (exppatternmode[i] == 1):
                   #if do_print == 1:
                       #print "Self contained"
                   expdb_linestart.append(int(lstart))
                   expdb_colstart.append(int(cstart))
                   expdb_lineend.append(int(lend))
                   expdb_colend.append(int(cend))
                   expdb_elineend.append(int(lend))
                   expdb_ecolend.append(int(cend))
                   expdb_exptext.append(linebuf[lineindex])
                   expdb_in_c_file.append(in_parsed_file)
                   expdb_tab.append(tab)
                   expdb_exppatternmode.append(1)
                   expdb_func.append(current_function)
                   if not in_parmdecl:
                       expdb_secstackvars.append(secStackVars.copy())
                   else:
                       expdb_secstackvars.append([])
                   expdb_index +=1

               # Need to look for last sub expression
               if (exppatternmode[i] == 2):
                   cur_lstart = int(lstart)
                   cur_cstart = int(cstart)
                   cur_lend = int(lend)
                   cur_cend = int(cend)
                   cur_tab = tab
                   expdb_linestart.append(int(lstart))
                   expdb_colstart.append(int(cstart))
                   expdb_elineend.append(int(lend))
                   expdb_ecolend.append(int(cend))
                   expdb_exptext.append(linebuf[lineindex])
                   expdb_in_c_file.append(in_parsed_file)
                   expdb_exppatternmode.append(2)
                   #if do_print == 1:
                        #print("START: (" + lstart + "," + cstart + ")")
                   inside_expression = lineindex

               # Need to look for last sub expression. Also need to add length of keyword
               if (exppatternmode[i] > 2):
                   cur_lstart = int(lstart)
                   cur_cstart = int(cstart) + exppatternmode[i]
                   cur_lend = int(lend)
                   cur_cend = int(cend)
                   cur_tab = tab
                   expdb_linestart.append(int(lstart))
                   expdb_colstart.append(int(cstart) + exppatternmode[i])
                   expdb_elineend.append(int(lend))
                   expdb_ecolend.append(int(cend))
                   expdb_exptext.append(linebuf[lineindex])
                   expdb_in_c_file.append(in_parsed_file)
                   expdb_exppatternmode.append(2)
                   #if do_print == 1:
                        #print("START: (" + lstart + "," + cstart + ")")
                   inside_expression = lineindex

            i+=1

    if (rightself) or (middleself and not rightother) or (anyposself and not middleother and not rightother):
        in_parsed_file = 1

    # If lstart or curstart moved forward in parsed c file, update
    if ( line_position_updated and in_parsed_file and (int(lstart) > int(last_lstart))):
        last_lstart=lstart
        last_cstart=cstart
        if do_print:
            print("Line moving forward! last_lstart:" + last_lstart + " last_cstart:" + last_cstart)

    if ( col_position_updated and in_parsed_file and (int(lstart) == int(last_lstart)) and ( int(cstart) > int(last_cstart) ) ):
        last_cstart=cstart
        if do_print:
            print("Column moving forward! last_lstart:" + last_lstart + " last_cstart:" + last_cstart)

    # Update lstart and cstart to reflect the position BEFORE THE NEXT expression, and not beginning iof the last in this one. See above...
    lstart = lend
    cstart = cend

    print("Line: " + linebuf[lineindex])
    print("in parsed file: " + str(in_parsed_file))

    # update section info and any declarations
    if not inside_expression and not skip_scope and in_parsed_file and numDataVars > 0:
        currentSectionLend = int(skiplend)
        currentSectionCend = int(skipcend)

        # push new sections

        # var declarations in parameter declarations
        for section in re_parmdeclarations:
            m = section.match(linebuf[lineindex])
            if m:
                print("MATCHED PARM DECL: " + linebuf[lineindex])
                break

        # TODO: Add lvalue vars

        if m and not backtrailing:
            # top level ?
            top = True
            count = 0
            for l, c in secStackPos:
                if l != sys.maxsize:
                    top = False
                    break
                count += 1

            if top:
                secStackPos.append((sys.maxsize, 0))
                secStackVars.append(m.group(2))
            else:
                # copy scope, add new var
                scope = secStackPos.pop()
                secStackPos.append(scope)
                secStackPos.append(scope)
                secStackVars.append(m.group(2))

        else:
            # Skip?
            skipthis = False
            for section in re_skip_scopes:
                m = section.match(linebuf[lineindex])
                if m:
                    skipthis = True

            # Barrier?
            for section in re_var_barriers:
                barrier = section.match(linebuf[lineindex])
                if barrier:
                    secStackVars.append("### VAR BARRIER ###")
                    secStackPos.append((currentSectionLend, currentSectionCend))
                    print("MATCHED VAR BARRIER: " + linebuf[lineindex])
                    break

            if not skipthis and not barrier:
                secStackVars.append("")
                secStackPos.append((currentSectionLend, currentSectionCend))

    print("Scope stack after decl check: ")
    print(secStackPos)
    print(secStackVars)

    # Finally, update input file line index
    lineindex+=1


# If we were inside an expression when the file ended, take care of the last one
if inside_expression:
    expdb_lineend.append(int(lstart))
    expdb_colend.append(int(cstart) - 1)
    expdb_tab.append(tab)
    expdb_func.append(current_function)
    if not in_parmdecl:
        expdb_secstackvars.append(secStackVars.copy())
    else:
        expdb_secstackvars.append([])
    expdb_index +=1


# Open probe expression data file to append entries
exp_pdf = open(sys.argv[4], "w")

# Open probe data file to start append entries
pdf = open(sys.argv[3], "w")

printSecStackVars()

# Insert probes
if do_print:
    print("Probing starting at {}".format(parsed_file))

i=0
while (i < expdb_index):
    bail_out=0
    ls = expdb_linestart[i] - 1
    cs = expdb_colstart[i] - 1
    le = expdb_lineend[i] - 1
    ce = expdb_colend[i] #- 1
    ele = expdb_elineend[i] - 1

    probe_prolog = "(DMCE_PROBE(TBD"

    if numDataVars > 0:
        vlist = []
        for s in reversed(expdb_secstackvars[i]):
            if s == "### VAR BARRIER ###":
                break
            if s != "":
                vlist.append(s)

        count = 0
        if len(vlist) > 0:
            probe_prolog = probe_prolog + ","
            for s in vlist:
                probe_prolog = probe_prolog + "(" + tvtype + ")" + s
                count += 1
                if (count == numDataVars):
                    break
                probe_prolog = probe_prolog + ","

        while (count < numDataVars):
            count += 1
            if count == 1:
                probe_prolog = probe_prolog + ",0,"
            elif count == numDataVars:
                probe_prolog = probe_prolog + "0"
            else:
                probe_prolog = probe_prolog + "0,"

    probe_prolog = probe_prolog + "), "

    if (expdb_exppatternmode[i] == 2 ):
        ece = expdb_ecolend[i]
    else:
        ece = expdb_ecolend[i] - 1

    tab = expdb_tab[i]

    # Sanity check input

    # Ends before start?
    if ((ls == ele) and (ece <= cs)):
        bail_out=1

    if do_print:
        print(str(expdb_in_c_file[i]) + "  EXP:" + expdb_exptext[i].rstrip() + "STARTPOS: (" + str(ls) + "," + str(cs) + ")" + "ENDPOS: (" + str(le) + "," + str(ce) + ")" + "ECE: " + str(ece) + "Tab: " + str(tab))

    #single line
    #    if (ls==le):
    if (0):
       if (ls not in probed_lines):
            line = pbuf[ls]

            iline = line[:cs] + "(DMCE_PROBE(TBD)," + line[cs:ce+1] + ")" + line[ce+1:]
            if do_print:
                print("Old single line: " + line.rstrip())
            if do_print:
                print("New single line: " + iline.rstrip())
            pbuf.pop(ls)
            pbuf.insert(ls,iline)
            probed_lines.append(ls)
            if do_print:
                print("1 Added line :" + str(ls))
            pdf.write(parsed_file + ":" + str(ls) + "\n")
    else:
        # Multiple lines
        # Insert on first line and last line
        # mark all lines in between as probed
        # Also, adjust le and ce if a ; or a ) is found before

        if (ls not in probed_lines):
            lp=ls
            while (lp < ele):
                probed_lines.append(lp)
                if do_print:
                    print("2 Added line :" + str(lp))
                lp +=1

            cp=ece

            found=0
            if do_print:
                print("Searching from (" + str(lp+1) + "," + str(cp) + ")")
            stack_curly=0
            stack_parentesis=0
            stack_bracket=0
            while ((lp < len(pbuf)) and not found and not bail_out):
                line = pbuf[lp].rstrip()

                #Bail out candidates to MAYBE be fixed later
                if ("#define" in line):
                    bail_out=1

                # Filter out escaped backslash
                line = re.sub(r'\\\\', "xx", line)

                # Filter out escaped quotation mark and escaped apostrophe
                line = re.sub(r'\\"', "xx", line)
                line = re.sub(r"\\'", "xx", line)

                # Replace everything within '...' with xxx
                line_no_strings = list(line)
                p = re.compile("'.*?'")
                for m in p.finditer(line):
                    j=0
                    while (j < len(m.group())):
                        line_no_strings[m.start() + j] = 'x'
                        j = j + 1

                line = "".join(line_no_strings)

                # Replace everything within "..." with xxx
                line_no_strings = list(line)
                p = re.compile("\".*?\"")
                for m in p.finditer(line):
                    j=0
                    while (j < len(m.group())):
                        line_no_strings[m.start() + j] = 'x'
                        j = j + 1

                line = "".join(line_no_strings)

                # Replace everything within /*...*/ with xxx
                line_no_strings = list(line)
                p = re.compile("\/\*.*?\*\/")
                for m in p.finditer(line):
                    j=0
                    while (j < len(m.group())):
                        line_no_strings[m.start() + j] = 'x'
                        j = j + 1

                line = "".join(line_no_strings)

                tail = line[cp:]
                if do_print:
                    print("LINE: " + line)
                if do_print:
                    print("TAIL: " + tail)

                # Find first ) } ] or comma that is not inside brackets of any kind
                pos_index = 0
                while (pos_index < len(tail)):
                    # Curly brackets
                    if (tail[pos_index] == "}"):
                        stack_curly-=1
                    if (tail[pos_index] == "{"):
                        stack_curly+=1
                    if (stack_curly == -1):
                        break


                    # Brackets
                    if (tail[pos_index] == "]"):
                        stack_bracket-=1
                    if (tail[pos_index] == "["):
                        stack_bracket+=1
                    if (stack_bracket == -1):
                        break


                    # Parentesis
                    if (tail[pos_index] == ")"):
                        stack_parentesis-=1
                    if (tail[pos_index] == "("):
                        stack_parentesis+=1
                    if (stack_parentesis == -1):
                        break

                    # Comma, colon, questionmark (only valid if not inside brackets)
                    if (stack_parentesis == stack_bracket == stack_curly == 0 ):
                        if (tail[pos_index] == ","):
                            break
                        # Question mark
                        if (tail[pos_index] == "?"):
                            break
                        # Colon
                        if (tail[pos_index] == ":"):
                            break

                    # Semicolon (always valid)
                    if (tail[pos_index] == ";"):
                        break

                    pos_index+=1

                if do_print:
                    print("index: " + str(pos_index))

                if (pos_index < len(tail) and not bail_out):
                    found=1
                    cp += pos_index

                    # NOTE! Lines commented out prevents us to go further lines down than the actual expression was.
                    # Not sure if we need them, leave commented out for now.

#                    if (lp < le):
                    le = lp
                    ce = cp
#                    elif (lp == le):
##                        if (cp < ce):
#                        ce = cp

                    if do_print:
                        print("FOUND EARLY: (" + str(le+1) + "," + str(ce) + ") in:" + pbuf[lp].rstrip())


                cp=0 # All following lines need to be searched from beginnning of line
                probed_lines.append(lp)
                if do_print:
                    print("3 Added line :" + str(lp+1))
                lp+=1

            # pre insertion
            if (not bail_out):
                line = pbuf[ls]

                match_exclude = 0
                for re_exp in re_cxl_list:
                    j=0
                    while (ls + j) <= le:
                        if do_print == 2:
                            print("searching for '{}' in '{}'".format(re_exp.pattern, pbuf[ls + j]))
                        if (re_exp.match(pbuf[ls + j])):
                            match_exclude = 1
                            if do_print == 1:
                                print("match_exclude=1")
                            break
                        j = j + 1

                    if match_exclude:
                        break

                if (not match_exclude):
                    # Pick line to insert prolog
                    iline_start = line[:cs] + probe_prolog + line[cs:]
                    if do_print:
                        print("Old starting line: " + line.rstrip())
                    if do_print:
                        print("New starting line: " + iline_start.rstrip())

                    # if start and end on same line, compensate column for inserted data
                    if (ls == le):
                        ce+= len(probe_prolog)

                    # Last time to regret ourselves! Check for obvious errors on line containing prolog. If more is needed create a list instead like for sections to skip!
                    regret = re_regret_insertion.match(iline_start)

                    if (not regret):
                        # Insert prolog
                        pbuf.pop(ls)
                        pbuf.insert(ls,iline_start)

                        # Pick line to insert epilog
                        if do_print:
                            print("Multi line INSERTION end: (" + str(le+1) +"," + str(ce) + ")" + ": " + line.rstrip())
                        line = pbuf[le]
                        iline_end = line[:ce] + probe_epilog + line[ce:]

                        # Print summary
                        if do_print:
                            print("Old ending line: " + line.rstrip())
                        if do_print:
                            print("New ending line: " + iline_end.rstrip())

                        # Insert epilog
                        pbuf.pop(le)
                        pbuf.insert(le,iline_end)

                        probes+=1

                        # Update probe file
                        pdf.write(parsed_file + ":" + str(ls) + ":" + expdb_func[i] + "\n")
                        tmp_exp = expdb_exptext[i].rstrip()
                        pat_i = 0
                        while (pat_i < len(exppatternlist)):
                            re_exp = re_exppatternlist[pat_i]
                            if (re.match(re_exp, tmp_exp)):
                                if do_print:
                                    print("-"*20)
                                    print("Assigning a Probe expression index")
                                    print("-"*20)
                                    print("Local Probe number: " + str(probes))
                                    print("EXP_index: " + str(pat_i))
                                    print("Matched with: " + re_exp.pattern)
                                    print("EXP string: " + tmp_exp)
                                    print("#"*5 + " TO NEW EXPRESSION FILE " + "#"*5)
                                exp_data = re.match(exp_pat, tmp_exp)
                                exp_type = exp_data.group(1).strip()
                                exp_operator = exp_data.group(2).strip()
                                if do_print:
                                    print("File: " + parsed_file)
                                    print("Local probe number: " + str(probes))
                                    print("EXPR index: " + str(pat_i))
                                    print("EXP: " + exp_type)
                                    print("Value: " + exp_operator)
                                    print("-"*100)
                                # Write output to the <exprdata>-file
                                # <c_file>:<line number>:<expression pattern index>:<full Clang expression>
                                exp_pdf.write(parsed_file + ":" + str(ls) + ":" + str(pat_i) + ":" + exp_data.group().rstrip() + "\n")

                                break
                            pat_i += 1



    i += 1

# write back c file
pf = open(sys.argv[2],"w")
for line in pbuf:
   pf.write(line)

pdf.close()
exp_pdf.close()

print('{:5.1f} ms {:5} probes'.format((time.time()-time1)*1000.0, probes))
