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

# Log prints from this program are expensive and therefore normally disabled
do_print=0

parsed_file = sys.argv[1]

# Disable probing all together?
no_probes = os.getenv('DMCE_NOPROBES')
if no_probes is not None:
    no_probes = True
else:
    no_probes = False

# Generate struct printout macros?
struct_printouts = os.getenv('DMCE_STRUCTS')
if struct_printouts is not None:
    gen_struct_macros = True
else:
    gen_struct_macros = False

# Get parser mode
parser_mode = os.getenv('DMCE_PARSER_MODE')
if parser_mode == "calltrace":
    function_trace = 1
else:
    function_trace = 0

# Get number of data variables
ndvs = os.getenv('DMCE_NUM_DATA_VARS')
if ndvs == None:
    numDataVars = 0
else:
    numDataVars = int(ndvs)

# Derefs allowed?
dereffs_allowed = True
dra = os.getenv('DMCE_ALLOW_DEREFERENCES')
if dra is not None and dra == "NO":
    dereffs_allowed = False

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


# Check what lines to exclude and include
fposexcl = []
posexcludelines = []
if os.path.exists(configpath + "/dmce.pos.exclude"):
    dmceposexclude = open(configpath + "/dmce.pos.exclude")
    posexcludelines = dmceposexclude.readlines()
    dmceposexclude.close()

fposincl = []
posincludelines = []
if os.path.exists(configpath + "/dmce.pos.include"):
    dmceposinclude = open(configpath + "/dmce.pos.include")
    posincludelines = dmceposinclude.readlines()
    dmceposinclude.close()

posexcludestart = []
posexcludeend = []

for line in posexcludelines:
    line = line.rstrip()
    if line != "" and not "#" in line:
        if ":" in line and "-" in line:
            if parsed_file == line.split(':')[0]:
                posexcludestart.append(int(line.split(':')[1].split('-')[0]))
                posexcludeend.append(int(line.split(':')[1].split('-')[1]))
        else:
            print("error: Format for dmce.pos.exclude and dmce.pos.include is 'file:line-line', abort", file=sys.stderr)
            sys.exit(1)

posincludestart = []
posincludeend = []

for line in posincludelines:
    line = line.rstrip()
    if line != "" and not "#" in line:
        if ":" in line and "-" in line:
            if parsed_file == line.split(':')[0]:
                posincludestart.append(int(line.split(':')[1].split('-')[0]))
                posincludeend.append(int(line.split(':')[1].split('-')[1]))
        else:
            print("error: Format for dmce.pos.exclude and dmce.pos.include is 'file:line-line', abort", file=sys.stderr)
            sys.exit(1)

parsed_file_exp = parsed_file
probe_prolog = "(DMCE_PROBE(TBD),"
probe_epilog = ")"

current_function = ""
current_function_sticky = ""
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
expdb_reffedvars = []
expdb_func = []
expdb_frp = []
expdb_index = 0

secStackPos = []
secStackVars = []
reffedVars = []

if gen_struct_macros:
    struct_src= []
    struct_src.append("\n#include <stdio.h>\n\n")

def printSecStackVars():
    i=0
    if do_print:
        print("SECSTACKVARS:")
    while (i < expdb_index):
        if do_print:
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
in_parmdecl_sticky = 0
in_parmdecl_tab  = 0
skip_backtrail = 0
skip_backtrail_tab = 0
skip_lvalue = 0
skip_lvalue_tab = 0

function_scope_tab = 0

function_returns_pointer = False

in_conditional_sequence_point = False
conditional_sequence_point_tab = 0
in_member_expr = False
member_expr_tab = 0


lineindex = 0

inside_expression = 0
in_parsed_file = 0
just_landed = 0
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

ftrace_infunc = False
ftrace_current_funcname = ""
ftrace_lend = 0
ftrace_cend = 0

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

# ..and the same for the AST file
#if gen_struct_macros:
#    # Snoop the ast file from the location of the probe data file
#    ast_file = open(sys.argv[3].replace(".probedata", "") + ".ast", "r")
#    rawastbuf = ast_file.readlines()
#    ast_file.close()
#    astbuf = []
#    for line in rawastbuf:
#        # Make built-in functions look like lib functions
#        line = re.sub("<built\-in>", "dmce_built_in.h", line)
#        # Make scratch space look like include file ref
#        line = re.sub("<scratch space>", "dmce_scratch_space.h", line)
#        # Remove all "nice info" pointing to include files
#        line = re.sub("\(.* at .*\)", "", line)
#        astbuf.append(line)

linestotal=rawlinestotal

# Regexps for C/C++ expression recognition
if no_probes:
    exppatternlist = []
    exppatternmode = []
elif configpath != None and os.path.isfile(configpath + '/recognizedexpressions.py'):
    sys.path.insert(1, configpath)
    import recognizedexpressions
    exppatternlist = recognizedexpressions.exppatternlist
    exppatternmode = recognizedexpressions.exppatternmode
else:
    exppatternlist = ['.*-CallExpr\sHexnumber\s<.*\,.*>.*',
                      '.*-CXXMemberCallExpr\sHexnumber\s<.*\,.*>.*',
                      '.*-CXXNewExpr\sHexnumber\s<.*\,.*>.*',
                      '.*-CXXDeleteExpr\sHexnumber\s<.*\,.*>.*',
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
                      '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\*\=\'.*',
                      '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\/\=\'.*',
                      '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\%\=\'.*',
                      '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\&\=\'.*',
                      '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\|\=\'.*',
                      '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\^\=\'.*',
                      '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\<<\=\'.*',
                      '.*CompoundAssignOperator Hexnumber <.*\,.*>.*\'\>>\=\'.*',
                      '.*ReturnStmt Hexnumber <.*\,.*>.*']

    # Modes:
    #  1    Contained space, use as is
    #  2    Free, need to look for next
    #  x    Free, look for next at colpos + x
    exppatternmode = [2,2,2,2,1,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,6]

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

re_file_ref_anypos            = re.compile(r'.*<(.*\.c|.*\.cpp|.*\.cc|.*\.c|.*\.h|.*\.hh|.*\.hpp):\d*:\d*.*')
re_file_ref_middle          = re.compile(r'.*\, (.*\.c|.*\.cpp|.*\.cc|.*\.h|.*\.hh|.*\.hpp):.*>.*')
re_file_ref_right           = re.compile(r'.*<.*> (.*\.c|.*\.cpp|.*\.cc|.*\.h|.*\.hh|.*\.hpp):.*')
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
re_sections_to_not_skip.append(re.compile(r'.*CXXRecordDecl Hexnumber.*(referenced|implicit) class.*'))
re_sections_to_not_skip.append(re.compile(r'.*CXXRecordDecl Hexnumber.*class.*definition.*'))

# The ones to skip
re_sections_to_skip = []
re_sections_to_skip.append(re.compile(r'.*-VarDecl Hexnumber.*const.*'))
re_sections_to_skip.append(re.compile(r'.*-InitListExpr.*'))
re_sections_to_skip.append(re.compile(r'.*RecordDecl Hexnumber.*'))
re_sections_to_skip.append(re.compile(r'.*-EnumDecl Hexnumber.*'))
re_sections_to_skip.append(re.compile(r'.*<.*>.*\sconstexpr\s.*'))
re_sections_to_skip.append(re.compile(r'.*-TemplateArgument expr.*'))
re_sections_to_skip.append(re.compile(r'.*-StaticAssertDecl.*'))
re_sections_to_skip.append(re.compile(r'.*UnaryOperator Hexnumber.*lvalue prefix \'*\'.*'))

# Parameter and variable declarations
re_sections_parmdecl = []
re_sections_parmdecl.append(re.compile(r'.*-ParmVarDecl Hexnumber.*'))
re_sections_parmdecl.append(re.compile(r'.*-VarDecl Hexnumber.*'))

# Variable stack barriers
re_var_barriers = []
re_var_barriers.append(re.compile(r'.*-CXXRecordDecl.*'))
re_var_barriers.append(re.compile(r'.*-LambdaExpr.*'))

# Variable and param var declarations
re_parmdeclarations = []
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'size_t\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'size_t\':\'unsigned long\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s(\'long\'|\'long\':\'long\') (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s(\'unsigned long\'|\'unsigned long\':\'unsigned long\') (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s(\'int\'|\'int\':\'int\') (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s(\'unsigned int\'|\'unsigned int\':\'unsigned int\') (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'.* \*\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s\'.* \*\*\' (cinit|listinit).*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'size_t\':\'unsigned long\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'size_t\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'long\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'unsigned long\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'int\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'unsigned int\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'.* \*\'.*'))
re_parmdeclarations.append(re.compile(r'.*-ParmVarDecl Hexnumber.*(used)\s(\S*)\s\'.* \*\*\'.*'))

# Match any vardecl

re_vardecl = re.compile(r'.*-VarDecl Hexnumber.*(used|referenced)\s(\S*)\s.*')

# Variable and param var declarations to ignore
re_parmdeclarations_ignore = []
re_parmdeclarations_ignore.append(re.compile(r'.*\'std::string\'.*'))   # Clang 10 sometimes confuses string.length() with de-reffed member variable type

# De-reffed member vars and pointers
re_memberdeclarations = []
re_memberdeclarations.append(re.compile(r'.*-MemberExpr Hexnumber <.*>.*\'(.* \*|.* \*\*|int|long|unsigned int|unsigned long|short|unsigned short|char|unsigned char)\' lvalue (->\w*).*'))
re_memberdeclarations.append(re.compile(r'.*-MemberExpr Hexnumber <.*>.*\'(.* \*|.* \*\*|int|long|unsigned int|unsigned long|short|unsigned short|char|unsigned char)\' lvalue (\.\w+).*'))
re_memberdeclarations.append(re.compile(r'.*-UnaryOperator Hexnumber <.*>.*\'(.* \*|.* \*\*|int|long|unsigned int|unsigned long|short|unsigned short|char|unsigned char)\' lvalue prefix \'(\*)\' .*'))

re_submemberdeclarations = re_memberdeclarations.copy()
re_submemberdeclarations.append(re.compile(r'.*-MemberExpr Hexnumber <.*>.*\'(.*)\' lvalue (\.\w+).*'))

re_memberdeclarations_ignore = []
re_memberdeclarations_ignore.append(re.compile(r'.*\'std::string\'.*'))   # Clang 10 sometimes confuses string.length() with de-reffed member variable type

# Conditional sequence points
re_csp_list = []
re_csp_list.append(re.compile(r'.*BinaryOperator.*(\'\|\|\'|\'\&\&\').*'))

# Declaration reference
re_declref = re.compile(r'.*-DeclRefExpr Hexnumber.*Var Hexnumber \'(\S*)\' \'.*\'.*')

# function trace entry triggers
re_ftrace_entry = []
re_ftrace_entry.append(re.compile(r'.*-FunctionDecl.*'))
re_ftrace_entry.append(re.compile(r'.*-CXXMethodDecl.*'))
re_ftrace_entry.append(re.compile(r'.*-CXXConstructorDecl.*'))
re_ftrace_entry.append(re.compile(r'.*-CXXDestructorDecl.*'))

# Functions that returns pointer
re_function_returns_pointer = []
re_function_returns_pointer.append(re.compile(r'.*-FunctionDecl.*\'\w* \*\(.*'))
re_function_returns_pointer.append(re.compile(r'.*-CXXMethodDecl.*\'.* \*\(.*'))

re_return_zero = re.compile(r'.*return\(DMCE_PROBE.*\)\,\s*0\s*\)')
resub_return_zero = re.compile(r'\,\s*0\s*\)')

# Accepted function trace compound
re_ftrace_compound = re.compile(r'.*CompoundStmt Hexnumber.*, line:(\d*):(\d*)>.*')

# function trace return statement
re_ftrace_return_statement = re.compile(r'.*ReturnStmt Hexnumber <.*\,.*>.*')

# Variable references
re_reffedvars = []
re_reffedvars.append(re.compile(r'.*DeclRefExpr\sHexnumber.*Var\sHexnumber\s\'(\w*)\'.*'))

# scopes to skip
re_skip_scopes = []
re_skip_scopes.append(re.compile(r'.*-DeclStmt Hexnumber.*'))

# AST entries to skip
re_skip_ast_entry = re.compile(r'.*(<<NULL>>|<<invalid sloc>>).*')

# Attributes cant backtrail, so special case for them
re_is_attribute = re.compile(r'.*Attr Hexnumber.*')


# Populate struct database
re_recorddecl = re.compile('.*RecordDecl.*(struct) (\S*).*')
re_typedefdecl = re.compile('.*-TypedefDecl.* referenced (\w*) \'.*')
re_fielddecl = re.compile('.*-FieldDecl .* (.*) \'(size_t|int|unsigned int|long|unsigned long|.* \*)\'.*')

def find_data_structures():
    if (in_parsed_file):
        m = re_recorddecl.match(linebuf[lineindex])
        if m:
            if do_print:
                print("FOUND RECORD!")
            struct_name = m.group(2)
            field_names = []
            i = lineindex + 1
            while i < len(linebuf):
                # Check for sections to skip within the record declaration
                if "DefinitionData" in linebuf[i]:
                    tabpos = linebuf[i].find("|-")
                    i += 1
                    while linebuf[i].find("|-") > tabpos:
                        i += 1
                elif "FieldDecl" in linebuf[i]:
                    m = re_fielddecl.match(linebuf[i])
                    if m:
                        if do_print:
                            print("FOUND FIELD!")
                        field_names.append(m.group(1))
                    i += 1
                else:
                    # typedef struct { ... } A; ? => Look for definition of A
                    if struct_name == "definition":
                        m = re_typedefdecl.match(linebuf[i])
                        if m:
                            struct_name = m.group(1)
                            if do_print:
                                print("FOUND TYPEDEF")
                        else:
                            field_names = []
                            if do_print:
                                print("NO TYPEDEF FOUND, CLEANING FIELDS")
                    break
            if len(field_names) > 0:
                struct_src.append("\n#ifndef DMCE_STRUCT_API_" +  struct_name + "\n")
                struct_src.append("\n#define DMCE_STRUCT_API_" +  struct_name + "\n")
                struct_src.append("#define dmce_print_" + struct_name + "(p) {\\\n")
                struct_src.append("    fprintf(stderr, \"DMCE struct output: " + struct_name + " \" #p \"" + "\\n\");\\\n")
                for field in field_names:
                    struct_src.append("    fprintf(stderr, \"    \" #p \"->" + field + ": %lx\\n\", (uint64_t)p->" + field + ");\\\n")
                struct_src.append("} while (0)\n\n")
                struct_src.append("#endif\n")

def clean_stackvars():
    i = 0
    while (i < len(secStackVars)):
        # remove the member de-refs
        if "$" in secStackVars[i]:
            secStackVars.pop(i)
            secStackPos.pop(i)
        else:
            # activate struct member vars
            secStackVars[i] = secStackVars[i].replace("¤","")
            i+=1

# Populate c expression database
while (lineindex < linestotal):
    if do_print:
        print("---------------------")
        print("Pre-filtered AST line:           " + linebuf[lineindex])

    linebuf[lineindex] = linebuf[lineindex].replace(", <invalid sloc>","")
    linebuf[lineindex] = linebuf[lineindex].replace("<invalid sloc>, ","")
    if re_skip_ast_entry.match(linebuf[lineindex]):
        if do_print:
            print("Skipped ast entry!")
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
    if (in_conditional_sequence_point) and (tab <= conditional_sequence_point_tab):
        in_conditional_sequence_point = False
    if (in_member_expr) and (tab <= member_expr_tab):
        in_member_expr = False

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
    is_attribute = False

    if re_is_attribute.match(linebuf[lineindex]):
        is_attribute = True

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

    # Normal regexp
    found_section_to_skip=0
    for section in re_sections_to_skip:
        m = section.match(linebuf[lineindex])
        mnot = False
        for not_section in re_sections_to_not_skip:
            if not_section.match(linebuf[lineindex]):
                mnot = True
        if (m and not mnot):
            found_section_to_skip = 1

    # special case for some attributes
    # pragma unroll
    if lineindex < (len(linebuf) + 1) and "AttributedStmt" in linebuf[lineindex] and "LoopHintAttr" in linebuf[lineindex + 1]:
        found_section_to_skip = 1

    # Act if skip this section
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
    for re_f in re_func_inc_list:
        f_m = re_f.match(linebuf[lineindex])
        if f_m:
            current_function = f_m.group(1)
            if not in_function_scope:
                in_function_scope = True
                function_scope_tab = tab

    # Check for conditional sequence points && and || TODO: add ?
    for re_csp in re_csp_list:
        if not in_conditional_sequence_point and re_csp.match(linebuf[lineindex]):
            in_conditional_sequence_point = True
            conditional_sequence_point_tab = tab

    # Get a copy of linebuf[lineindex] without argument list to only search func names
    argsstripped = re.sub('\'.*\'','',linebuf[lineindex])

    # Check if exit function scope
    if in_function_scope:
        for re_f in re_func_excl_list:
            if re_f.match(argsstripped):
                in_function_scope = False

    if do_print:
        print("Parsed file: " + parsed_file)
        print("Parsed AST line:                     " + linebuf[lineindex])
        print("Position => " + "start: " + lstart + ", " + cstart + "  end: " + lend + ", " + cend + "  skip (end): " + skiplend + ", " + skipcend + "  scope (start): " + scopelstart + ", " + scopecstart + "  exp (end): " + str(cur_lend) + ", " + str(cur_cend))
        print("Flags => " + " in parsed file: " + str(in_parsed_file) +  " skip: " + str(skip) + " trailing: " + str(trailing) + " backtrailing: " + str(backtrailing) + " inside expression: " + str(inside_expression) + " skip scope: " + str(skip_scope) + "in parmdecl: " + str(in_parmdecl) + " sct: " + str(skip_scope_tab) + " infuncscope: " + str(in_function_scope) + " in_conditional_sequence_point: " + str(in_conditional_sequence_point) + " in_member_expr: " + str(in_member_expr) + " FRP: " + str(function_returns_pointer) )

    # ...and this is above. Check if found (almost) the end of an expression and update in that case
    if inside_expression:
        if do_print:
            print("Inside expresson wating to pass l: " + str(cur_lend) + "   c: " + str(cur_cend))
        # If we reached the last subexpression in the expression or next expression or statement
        if ( (int(scopelstart) > cur_lend) or ( (int(scopelstart) == cur_lend) and (int(scopecstart) > cur_cend) ) ):
            expdb_lineend.append(int(lstart))
            expdb_colend.append(int(cstart) -1 )
            expdb_tab.append(tab)
            expdb_func.append(current_function_sticky)
            if not in_parmdecl_sticky:
                expdb_secstackvars.append(secStackVars.copy())
                expdb_reffedvars.append(reffedVars.copy())
            else:
                expdb_secstackvars.append([])
                expdb_reffedvars.append([])
            # Clean any member refs
            clean_stackvars()

            expdb_index +=1
            if do_print:
                print("FOUND END/NEXT (" + linebuf[lineindex].rstrip() + ")  FOR  (" + linebuf[inside_expression].rstrip() + ")")
            inside_expression = 0
#            cur_lend = 0
#            cur_cend = 0

    # Special case: We can always pop the stack as far as possible at function entries
    at_func_entry = False
    if "-FunctionDecl" in linebuf[lineindex] or "-CXXMethodDecl" in linebuf[lineindex]:
        at_func_entry = True

        # Does the function return a pointer?
        function_returns_pointer = False
        for frp in re_function_returns_pointer:
            if frp.match(linebuf[lineindex]):
                function_returns_pointer = True

    # pop section stack?
    # any vardecl overriding a previously declared var (in the greater scope) needs to be removed from the var stack

    m  = re_vardecl.match(linebuf[lineindex])
    if m:
        vardecl = m.group(2)
    else:
        vardecl = "´"

    if ((in_parsed_file or at_func_entry) and numDataVars > 0):
        i = 0
        while (i < len(secStackPos)):
            l, c = secStackPos[i]
            if (secStackVars[i] == vardecl) or (int(scopelstart) > l) or ((int(scopelstart) == l) and (int(scopecstart) > c)):
                secStackVars.pop(i)
                secStackPos.pop(i)
            else:
                i+=1

#        while True:
#            if len(secStackPos) > 0:
#                l, c = secStackPos[len(secStackPos) - 1]
#                if (int(scopelstart) > l) or ((int(scopelstart) == l) and (int(scopecstart) > c)):
#                    secStackPos.pop()
#                    secStackVars.pop()
#                else:
#                    break
#            else:
#                break

    if do_print:
        print("Scope stack after pop check: ")
        print(secStackPos)
        print(secStackVars)

    if ((trailing) and (is_addition) and (not backtrailing) and (not inside_expression) and (not skip) and (not skip_backtrail) and (not skip_lvalue) and (in_function_scope)):
        if function_trace and not re_ftrace_return_statement.match(linebuf[lineindex]):

            i = 0
            while i < len(re_ftrace_entry):
                re_exp = re_ftrace_entry[i]
                m = re_exp.match(linebuf[lineindex])
                if m:
                    ftrace_infunc = True
                    ftrace_lend = skiplend
                    ftrace_cend = skipcend
                    if do_print:
                        print("Function entry detected ending at" + ftrace_lend + ":" + ftrace_cend + " :" + linebuf[lineindex])
                    break
                i += 1

            if ftrace_infunc:
                m = re_ftrace_compound.match(linebuf[lineindex])
                if m:
                     if do_print:
                        print("Compound detected (ending at " + m.group(1) + ":" + m.group(2) + ") : " + linebuf[lineindex])
                     if ftrace_lend == m.group(1) and ftrace_cend == m.group(2):
                        ftrace_infunc = False
                        if do_print:
                            print("Compound detected for endmark: " + ftrace_lend + ":" + ftrace_cend)
                            print("Compound start: " + lstart + ":" + cstart)

                        # entry
                        lpos = int(lstart)
                        cpos = int(cstart) + 1
                        expdb_linestart.append(lpos)
                        expdb_colstart.append(cpos)
                        expdb_lineend.append(lpos)
                        expdb_colend.append(cpos)
                        expdb_elineend.append(lpos)
                        expdb_ecolend.append(cpos)
                        expdb_exptext.append(linebuf[lineindex])
                        expdb_in_c_file.append(in_parsed_file)
                        expdb_tab.append(tab)
                        expdb_frp.append(function_returns_pointer)
                        expdb_exppatternmode.append(-1)
                        expdb_func.append(current_function)
                        expdb_secstackvars.append(secStackVars.copy())
                        expdb_reffedvars.append(reffedVars.copy())
                        clean_stackvars()
                        expdb_index +=1

                        # exit
                        lpos = int(ftrace_lend)
                        cpos = int(ftrace_cend)
                        expdb_linestart.append(lpos)
                        expdb_colstart.append(cpos)
                        expdb_lineend.append(lpos)
                        expdb_colend.append(cpos)
                        expdb_elineend.append(lpos)
                        expdb_ecolend.append(cpos)
                        expdb_exptext.append(linebuf[lineindex])
                        expdb_in_c_file.append(in_parsed_file)
                        expdb_tab.append(tab)
                        expdb_frp.append(function_returns_pointer)
                        expdb_exppatternmode.append(-2)
                        expdb_func.append(current_function)
                        expdb_secstackvars.append(secStackVars.copy())
                        expdb_reffedvars.append(reffedVars.copy())
                        clean_stackvars()
                        expdb_index +=1

        elif (exp_extra):
            i = 0
            while (i < len(re_exppatternlist)):
                re_exp = re_exppatternlist[i]
                if (re_exp.match(linebuf[lineindex])):
                   if do_print:
                       print("FOUND EXP: start: (" + lstart.rstrip() + "," + cstart.rstrip() + ")" + linebuf[lineindex].rstrip())

                   # Sanity check
                   if (int(lstart) > int(cf_len)):
                        if do_print:
                            print("ERROR: Got line position passed eof, file: " + parsed_file, file=sys.stderr)
                        sys.exit(1)
                   # save current function to use when expression is finally saved
                   current_function_sticky = current_function

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
                       expdb_frp.append(function_returns_pointer)
                       expdb_exppatternmode.append(1)
                       expdb_func.append(current_function)
                       if not in_parmdecl:
                           expdb_secstackvars.append(secStackVars.copy())
                           expdb_reffedvars.append(reffedVars.copy())
                       else:
                           expdb_secstackvars.append([])
                           expdb_reffedvars.append([])
                       clean_stackvars()
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
                       expdb_frp.append(function_returns_pointer)
                       #if do_print == 1:
                            #print("START: (" + lstart + "," + cstart + ")")
                       inside_expression = lineindex
                       in_parmdecl_sticky = in_parmdecl

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
                       expdb_frp.append(function_returns_pointer)
                       #if do_print == 1:
                            #print("START: (" + lstart + "," + cstart + ")")
                       inside_expression = lineindex
                       in_parmdecl_sticky = in_parmdecl

                i+=1

    just_landed = 0

    if (rightself) or (middleself and not rightother) or (anyposself and not middleother and not rightother):
        if in_parsed_file == 0:
            in_parsed_file = 1
            if middleself:
                just_landed = 1

    # If lstart or curstart moved forward in parsed c file, update
    if ( not is_attribute and not just_landed and line_position_updated and in_parsed_file and (int(lstart) > int(last_lstart))):
        last_lstart=lstart
        last_cstart=cstart
        if do_print:
            print("Line moving forward! last_lstart:" + last_lstart + " last_cstart:" + last_cstart)

    if ( not just_landed and col_position_updated and in_parsed_file and (int(lstart) == int(last_lstart)) and ( int(cstart) > int(last_cstart) ) ):
        last_cstart=cstart
        if do_print:
            print("Column moving forward! last_lstart:" + last_lstart + " last_cstart:" + last_cstart)

    # Update lstart and cstart to reflect the position BEFORE THE NEXT expression, and not beginning iof the last in this one. See above...
    lstart = lend
    cstart = cend

    if do_print:
        print("Line: " + linebuf[lineindex])
        print("in parsed file: " + str(in_parsed_file))

    # update section info and any declarations
    varname = ""
    found = 0
    lookforvars = not skip_scope and in_parsed_file and numDataVars > 0
    if lookforvars and not inside_expression:
        currentSectionLend = int(skiplend)
        currentSectionCend = int(skipcend)


        # var declarations in parameter declarations
        for section in re_parmdeclarations:
            m = section.match(linebuf[lineindex])
            if m:
                ignore_section = False
                for ignore in re_parmdeclarations_ignore:
                    if ignore.match(linebuf[lineindex]):
                        ignore_section = True
                        break
                if not ignore_section:
                    if do_print:
                        print("MATCHED PARM DECL: " + linebuf[lineindex])
                    varname = m.group(2)
                    found = 1
                    break

    if dereffs_allowed and inside_expression and not in_member_expr and not found and in_parsed_file and numDataVars > 0:
        foundmember = False
        member_offset = 0
        first_member_expr = True
        # This one is used to check that the last decl ref is really part of the same subnode
        tab_tail_check = 0
        # limit ourselves to 8 derefs
        while member_offset < 16 and (lineindex + member_offset + 2) < len(linebuf):
            matchmember = False
            if first_member_expr:
                re_membertmp = re_memberdeclarations
                first_member_expr = False
            else:
                re_membertmp = re_submemberdeclarations
            for section in re_membertmp:
                m = section.match(linebuf[lineindex + member_offset])
                if m:
                    ignore_member = False
                    for ignore in re_memberdeclarations_ignore:
                        if ignore.match(linebuf[lineindex]):
                            ignore_member = True
                            break
                    if not ignore_member:
                        # The pattern with ImpCast directly after is valid for member pointer derefs

                        if "ImplicitCastExpr" in linebuf[lineindex + member_offset + 1]:
                            varname = m.group(2) + varname
                            matchmember = True
                            member_offset += 2
                            tab_tail_check = 2
                            break
                        # The pattern with member directly after is valid for .member notation
                        elif "-MemberExpr" in linebuf[lineindex + member_offset + 1]:
                            varname = m.group(2) + varname
                            matchmember = True
                            member_offset += 1
                            tab_tail_check = 1
                            break
                        elif "-DeclRefExpr" in linebuf[lineindex + member_offset + 1]:
                            varname = m.group(2) + varname
                            member_offset += 1
                            tab_tail_check = 1
                            matchmember = True
                            break
                        else:
                            # skip if not following this pattern
                            member_offset += 1
                            tab_tail_check = 1
                            in_member_expr = True
                            member_expr_tab = tab

            if matchmember:
                if do_print:
                    print("MATCHED MEMBER DECL: " + linebuf[lineindex])
                foundmember = True
            else:
                break

        # If we are in a member expr that we do not handle, we still must skip underlaying member exprs
        if "-MemberExpr" in linebuf[lineindex] or "-ArraySubscriptExpr" in linebuf[lineindex]:
            in_member_expr = True
            member_expr_tab = tab

        if foundmember:
            foundrefdecl = False
            m = re_declref.match(linebuf[lineindex + member_offset])
            # Check for corresponding struct or class and make sure its a sub node
            if m:
                if do_print:
                    print("MATCHED REF DECL: " + linebuf[lineindex + member_offset])
                refname = m.group(1)
                foundrefdecl = True

        if foundmember and foundrefdecl and (refname + varname) not in secStackVars and linebuf[lineindex].find("|-") < linebuf[lineindex + tab_tail_check].find("|-") and not in_conditional_sequence_point:
            # member or pointer deref?
            if varname == "*":
                varname = "$*" + refname
            elif varname =="**":
                varname = "$**" + refname
            else:
                if "**" in varname:
                    varname = varname.replace("**", "")
                    varname = "$**" + refname + varname
                elif "*" in varname:
                    varname = varname.replace("*", "")
                    varname = "$*" + refname + varname
                else:
                    varname = "$" + refname + varname

            # If struct member notation, mark with ¤
            if "." in varname and "->" in varname:
                found = 0
            elif "." in varname:
                varname = varname.replace("$", "")
                varname = "¤" + varname
                found = 1
            else:
                found = 1

        # TODO: Add lvalue vars

    if found and not backtrailing:
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
            secStackVars.append(varname)
        else:
            # copy scope, add new var
            scope = secStackPos.pop()
            secStackPos.append(scope)
            secStackPos.append(scope)
            secStackVars.append(varname)

    elif lookforvars:
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
                if do_print:
                    print("MATCHED VAR BARRIER: " + linebuf[lineindex])
                break

        if not skipthis and not barrier:
            secStackVars.append("")
            secStackPos.append((currentSectionLend, currentSectionCend))

    if dereffs_allowed and in_parsed_file:
        # Check if any references to variables should be added to reffedVars
        for ref in re_reffedvars:
            m = ref.match(linebuf[lineindex])
            if m:
                if do_print:
                    print("MATCHED VAR REF: " + linebuf[lineindex])
                reffedvar = m.group(1)
                if reffedvar not in reffedVars:
                    reffedVars.append(reffedvar)
                else:
                    # move to most recent pos
                    reffedVars.append(reffedVars.pop(reffedVars.index(reffedvar)))
                break

    if do_print:
        print("Scope stack after decl check: ")
        print(secStackPos)
        print(secStackVars)
        print("Reffed vars:")
        print(reffedVars)

    # Any data structures starting here?
    if gen_struct_macros:
        find_data_structures()

    # Finally, update input file line index
    lineindex+=1

# If we were inside an expression when the file ended, take care of the last one
if inside_expression:
    expdb_lineend.append(int(lstart))
    expdb_colend.append(int(cstart) - 1)
    expdb_tab.append(tab)
    expdb_func.append(current_function_sticky)
    if not in_parmdecl_sticky:
        expdb_secstackvars.append(secStackVars.copy())
        expdb_reffedvars.append(reffedVars.copy())
    else:
        expdb_secstackvars.append([])
        expdb_reffedvars.append([])

    clean_stackvars()
    expdb_index +=1

# Open probe expression data file to append entries
exp_pdf = open(sys.argv[4], "w")

# Open probe data file to start append entries
pdf = open(sys.argv[3], "w")

printSecStackVars()

def afterburner(line, frp):
    if c_plusplus:
         print("IS CPLUSPLUS! Line: " + line)
         if frp and re_return_zero.match(line):
            print("RETURN ZERO MATCH!")
            print("Line before: " + line)
            line = re.sub(resub_return_zero, ", nullptr)", line)
            print("Line after: " + line)
    return line

# Insert probes
if do_print:
    print("Probing starting at {}".format(parsed_file))

i=0
while (i < expdb_index):
    out_of_position_scope = False
    bail_out=0
    ls = expdb_linestart[i] - 1
    cs = expdb_colstart[i] - 1
    le = expdb_lineend[i] - 1
    ce = expdb_colend[i] #- 1
    ele = expdb_elineend[i] - 1
    frp = expdb_frp[i]
    if do_print:
        print("___________FRP " + str(i) + "___________:" + str(frp))
        print(str(expdb_frp))
    probe_prolog = "(DMCE_PROBE(TBD"

    if numDataVars > 0:
        vlist = []
        for s in reversed(expdb_secstackvars[i]):
            if s == "### VAR BARRIER ###":
                break
            s = s.replace("$","")
            if s != "" and not "¤" in s:
                vlist.append(s)

        # Create a list ordered by last referenced
        lr_vlist = []
        for var in reversed(expdb_reffedvars[i]):
            if var in vlist:
                lr_vlist.append(var)

        # Fill up with declared ones that are not referenced if any
        if len(lr_vlist) < numDataVars:
            for s in vlist:
                if s not in lr_vlist:
                    lr_vlist.append(s)
                if len(lr_vlist) == numDataVars:
                    break

        count = 0
        if len(lr_vlist) > 0:
            for s in lr_vlist:
                probe_prolog = probe_prolog + ",(" + tvtype + ")" + s
                count += 1
                if (count == numDataVars):
                    break

            lr_vlist = lr_vlist[0:numDataVars]

#        while (count < numDataVars):
#            count += 1
#            if count == 1:
#                probe_prolog = probe_prolog + ",0,"
#            elif count == numDataVars:
#                probe_prolog = probe_prolog + "0"
#            else:
#                probe_prolog = probe_prolog + "0,"
        probe_prolog = probe_prolog.replace("DMCE_PROBE", "DMCE_PROBE" + str(count))

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

    # Check position filter to exclude or include, based on ls and cs
    for pindex in range(len(posincludestart)):
        if ls < (posincludestart[pindex] - 1)  or ls >= posincludeend[pindex]:
            out_of_position_scope = True

    for pindex in range(len(posexcludestart)):
        if ls >= (posexcludestart[pindex] - 1) and ls < posexcludeend[pindex]:
            out_of_position_scope = True

    if do_print:
        print(str(expdb_in_c_file[i]) + "  EXP:" + expdb_exptext[i].rstrip() + "STARTPOS: (" + str(ls) + "," + str(cs) + ")" + "ENDPOS: (" + str(le) + "," + str(ce) + ")" + "ECE: " + str(ece) + "Tab: " + str(tab))

    #single line
    #    if (ls==le):
    if not out_of_position_scope:
        if (expdb_exppatternmode[i] < 0):
           if (ls not in probed_lines):
                line = pbuf[ls]
                comment = "; /* Function entry: "
                if expdb_exppatternmode[i] == -2:
                    comment = "; /* Function exit: "

                # Due to a bug in clang-check sometimes adds 1 to the column position, we try
                # to mitigate by using any spaces to the left when inserting probes at the end

                if cs >= 2 and expdb_exppatternmode[i] == -2:
                    if line[cs-2] != ' ':
                        iline = line[:cs] + probe_prolog[1:len(probe_prolog) - 2] + comment + expdb_func[i] + " */ " + line[cs:]
                    else:
                        iline = line[:cs-1] + probe_prolog[1:len(probe_prolog) - 2] + comment + expdb_func[i] + " */ " + line[cs-1:]
                else:
                    iline = line[:cs] + probe_prolog[1:len(probe_prolog) - 2] + comment + expdb_func[i] + " */ " + line[cs:]

                iline = afterburner(iline, frp)

                if do_print:
                    print("Old single line: " + line.rstrip())
                if do_print:
                    print("New single line: " + iline.rstrip())
                pbuf.pop(ls)
                pbuf.insert(ls,iline)
                probed_lines.append(ls)
                probes += 1
                if do_print:
                    print("1 Added line :" + str(ls))
                pdf.write(parsed_file + ":" + str(ls) + ":" + expdb_func[i])
                for var in lr_vlist:
                    pdf.write( ":" + var)
                pdf.write("\n")

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
                            # Stream operator
                            if (tail[pos_index] == "<"):
                                tmp_index = 0
                                found_stream_operator = False
                                while (tmp_index < len(tail)):
                                    tmp_index += 1
                                    if (tail[pos_index + tmp_index] == "<"):
                                        found_stream_operator = True
                                        break
                                    elif (tail[pos_index + tmp_index] != " "):
                                        break
                                if found_stream_operator:
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

                        le = lp
                        ce = cp

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
                            iline_end = afterburner(iline_end, frp)
                            pbuf.insert(le,iline_end)
                            probes+=1

                            # Update probe file
                            if numDataVars == 0:
                                pdf.write(parsed_file + ":" + str(ls) + ":" + expdb_func[i] + "\n")
                            else:
                                pdf.write(parsed_file + ":" + str(ls) + ":" + expdb_func[i])
                                for var in lr_vlist:
                                    pdf.write( ":" + var)
                                pdf.write("\n")

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

if gen_struct_macros:
    sf = open(sys.argv[2] + ".dmcestructs","w")
    pf.write("#include \"" + os.path.basename(sys.argv[2]) + ".dmcestructs\"\n")
    for line in struct_src:
        sf.write(line)
    sf.close()

for line in pbuf:
    pf.write(line)

pf.close()
pdf.close()
exp_pdf.close()

print('{:5.1f} ms {:5} probes'.format((time.time()-time1)*1000.0, probes))
