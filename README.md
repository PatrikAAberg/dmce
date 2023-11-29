# DMCE (Did My Code Execute?)

Source code level instrumentation tool that enables dynamic code execution tracking *without HW or build tool chain dependencies*.

Probes c/c++ expressions added between two git revisions. Consists of a bunch of bash and python scripts on top of clang-check and git.


![Guis](https://github.com/PatrikAAberg/dmce/assets/22773714/c79a168f-6049-4ab6-bb0a-9574ef8c73a8)

## Probed code example

Before DMCE probing:

    int foo(int a) {

        return a + 42;
    }

    int bar(int b) {

        int c;

        c = foo(b);
        return c + 42;
    }

After DMCE probing:


    int foo(int a) {

        return(DMCE_PROBE(0), a + 42);
    }

    int bar(int b) {

        int c;

        (DMCE_PROBE(1),c = foo(b));

        return(DMCE_PROBE(2), c + 42);
    }

## Dependencies

git 2.10+

bash 4+

python 3+

clang

Normally works with clang-check (llvm) versions 10+

Currently recommended clang-check (llvm) version: 17 

## Install and setup

DMCE is currently installed using Ubuntu/Debian packages. To build an installable DMCE package from latest source:

    $ git clone https://github.com/PatrikAAberg/dmce.git
    $ cd dmce
    $ ./build-deb

You can also find the latest released package in "releases" to the right on this page. To install on Ubuntu/Debian:

    $ dpkg -i dmce-X.Y-Z.deb    # To uninstall: $ dpkg -r dmce

    $ dmce-setup

The above will install the neccesary executables, create a default .dmceconfig file at /home/$USER and a set up a DMCE configuration directory at /home/$USER/.config. Modify the files in this directory to directly control DMCE behaviour OR use the "dmce-set-profile" utility AND/OR use override switches available for the (dmce) tool itself. The first two will be persistent, the last one will be be used one-time only.

## Contents

#### [- Start here: A simple probing workflow example](#a-simple-probing-workflow-example) 
#### [- Trace](#trace) 
#### [- Trace GUI](https://github.com/PatrikAAberg/dmce-gui)
#### [- Patch coverage](#patch-code-coverage) 
#### [- Heatmap and data code coverage](#heatmap-and-data-code-coverage) 
#### [- Provoke race conditions](#provoke-race-conditions) 
#### [- DMCE command summary](#dmce-command-summary)
#### [- Probing pass configuration](#probing-pass-configuration)
#### [- Execution pass configuration](#execution-pass-configuration)

## A simple probing workflow example

This is a basic example just showing how DMCE probes are inserted without changing SW behaviour with respect to the original function.

    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    $ cd dmce-examples

Modify the DMCE configuration using the "dmce-set-profile" utility to use a printf probe. We want to include the "simple" directory and exclude the "simplecrash" directory:

    $ dmce-set-profile printf -i simple -e simplecrash

Run DMCE for all commits in the git, making it probe everything:

    $ dmce # for earlier verisions ( <= 1.8,1), use "dmce-launcher -aq"

Check the diff. You should be able to see the inserted DMCE probes.

    $ git diff

Go into the "simple" example folder, build the executable and run it.

    $ cd simple && ./build && ./simple

It builds and runs. Nothing functional-wise is changed,  but we have inserted hooks at all do-something-expressions. Using dmce-probe-XYZ.c files we can now extract information from code execution without tampering witch build tool chains. In this example, we have used a probe that simply prints to stderr the first time that position in the code is passed, and keep silent after that.

To go back to a non-probed state:

    $ cd ..
    $ dmce -c
    $ git diff

## Trace

DMCE can be used as a trace tool. There are two UIs, a terminal (see below) and a [graphical one](https://github.com/PatrikAAberg/dmce-gui).  

The following example shows how to find a null-pointer bug in an example program.

Dependencies:

    $ pip3 install colorama numpy

Set the DMCE profile to trace-mc, include only the "simplecrash" folder when inserting probes:

    $ dmce-set-profile trace-mc -i simplecrash

Run DMCE for all commits in the git:

    $ dmce

Go into the simplecrash example folder, build the executable and run it.

    $ cd simplecrash && ./build && ./simplecrash
    $ cd -

It crashes! Let's find out why.

    $ dmce-trace -t /tmp/${USER}/dmce/dmcebuffer.bin.[program name.pid] /tmp/${USER}/dmce/dmce-examples/probe-references.log $(pwd)

## Terminal UI
<img width="1180" alt="tgui" src="https://user-images.githubusercontent.com/22773714/169835252-d0d9716f-2dfc-447c-ae8d-b23a39bae3d0.png">

You might want something fancier than less to view your trace:
    
    $ dmce-set-profile trace-mc
    
    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    
    $ cd dmce-examples
    
    $ dmce
    
    $ cd threads
    
    $ ./build
    
    $ ./threads
    
    $ cd ..
    
    $ dmce-trace-viewer /tmp/${USER}/dmce/dmcebuffer.bin.[program name.pid] /tmp/${USER}/dmce/dmce-examples/probe-references.log $(pwd)

## Patch code coverage

This was the original use case for DMCE. How to check delta (between two git revisions) code coverage in gits without messing with their respective build or test systems? See example below.

    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    $ cd dmce-examples

Set up DMCE to do coverage, including only the "patchcov" directory:

    $ dmce-set-profile coverage -i patchcov

Apply the patch in the patchcov dir:

    $ pushd patchcov
    $ git apply 000-patchcov.patch
    $ popd

Probe the untracked and modified files, nothing more:

    $ dmce -n 1 --progress

Check that the patch was probed:

    $ git diff

Note, doxygen annotations are treated as code. Changing a doxygen comments may result in that following source code declaration gets instrumented.

Go into the patchcov directory again to build and run the tests. Note! Since the probe being used here can collect data from several executables, make sure to remove any old /tmp/$USER/dmce/dmcebuffer.bin file if it is not the intention to collect several runs in the same file:

    $ rm -f /tmp/$USER/dmce/dmcebuffer.bin
    $ cd patchcov
    $ ./build && ./test-patchcov

Use DMCE summary to display the results. For this example, we use a binary format probe, so the same goes for the summary:

    $ dmce-summary-bin -v /tmp/$USER/dmce/dmcebuffer.bin /tmp/$USER/dmce/dmce-examples/probe-references-original.log

The probe that was set up by "dmce-set-profile coverage" writes its output to /tmp/$USER/dmce/dmcebuffer.bin, so that's where we pick it up. Also note that the probe reference file used here is "probe-references-original.log" as opposed to "probe-references.log" that was used for the trace example. This is becasue for coverage, you want the line numbers coming from the original source code files and not the probed ones.
Anyway, the test passes with success! But wait, we also see that only half of the added probes were executed. And it could have been much worse...

## Heatmap and data code coverage

DMCE can be used to view frequently visited parts of your code as well as provide a form of data code coverage for your tests. To enable these features, simply use the --sort switch together with the dmce-trace command. Current available options for --sort are:

* heat        - What parts of your code are executed most frequently
* uniq        - How many of each unique variable content combination exist for each executed part of your code 
* collapse    - How many different variable content combinations exist for each executed part of our code

A simple example for the "heat" option:

    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    $ cd dmce-examples

Modify the DMCE configuration to use a trace probe, including only the "loops" folder:

    $ dmce-set-profile trace -i loops

Run DMCE for all commits in the git, making it probe everything:

    $ dmce -aq

Go into the loops example folder, build the executable and run it.

    $ cd loops && ./build && ./loops
    $ cd -

Remove the DMCE probes:

    $ dmce -c
    
Run dmce-trace with the sort option "heat" (notice we use the unprobed source tree, and therefore "probe-references-original.log"):

    $ dmce-trace --sort heat /tmp/${USER}/dmce/dmcebuffer.bin /tmp/${USER}/dmce/dmce-examples/probe-references-original.log $(pwd) | less

You should now be able to see the most visited parts of our program. Replace "heat" with "uniq" or "collapse" for the other views.

Please note! For larger execution runs, the DMCE trace buffer size need to be increased to get the full view and not just the last part of the ring buffer. How to adjust the size of the DMCE trace buffer is further descibred in the config section.

## Provoke race conditions

DMCE can also be used to provoke potential race conditions by intentionally insert randomized delays
through out the code. Each probe gets an individual randomized number between 0..32767 upon which it will spin
the same amount of cpu timestamps.

    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    $ cd dmce-examples
    $ dmce-set-profile racectrack
    $ dmce -aq
    $ cd simple && ./build && ./simple

## DMCE command summary

The following commands are listed in typical workflow order. For each command, please see their respective --help for further details.

| Command           | Description                                                                                                   |
|-------------------|---------------------------------------------------------------------------------------------------------------|
| dmce-setup        | Create a .dmceconfig file and a config directory in /home/$USER and /home/$USER/.config                       |
| dmce-set-profile  | Config file helper utility: Choose one of pre-defined configurations, add filters and change some behaviours  |
| dmce              | Insert probes in current git directory                                                                        |
| dmce-stats        | Get some stats (how many inserted probes etc.) from a probed git                                              |
| dmce-summary-bin  | Get a coverage / heatmap report (using the "coverage" profile)                                                |
| dmce-trace        | Generate a textual trace output (using the "trace-mc" or "trace" profile)                                     |
| dmce-trace-viewer | Launch an interactive trace viewer (using the "trace-mc" or "trace" profile)                                  |

## Entries in .dmceconfig

### Probing pass configuration
Configuration is stored in the file ".dmceconfig". If dmce finds this file in the root of the git being probed this copy will be used. If not found there, it will pick the one in the user's home directory (initially put there by dmce-setup, and later modified by dmce-set-profile).

| Entry                          | Description                                                                                           |
|--------------------------------|-------------------------------------------------------------------------------------------------------|
DMCE_MEMORY_LIMIT                |
DMCE_EXEC_PATH                   | 
DMCE_WORK_PATH                   |
DMCE_CONFIG_PATH                 |
DMCE_CMD_LOOKUP_HOOK             |
DMCE_DEFAULT_C_COMMAND_LINE      |
DMCE_DEFAULT_CPP_COMMAND_LINE    |
DMCE_DEFAULT_H_COMMAND_LINE      |
DMCE_NUM_DATA_VARS               |
DMCE_ALLOW_DEREFERENCES          |
DMCE_PROBE_SOURCE                |
DMCE_PROBE_PROLOG                |
DMCE_POST_HOOK                   |
DMCE_SYS_INCLUDES                |
DMCE_PROBE_TEMPLATES             |
DMCE_FIX_NULLPTR                 |
DMCE_TOP_LEVEL_VARS              |
DMCE_GIT_DIFF_ALGORITHM          |

### Execution pass configuration
It is possible to pass information to the running code by using DMCE_PROBE_DEFINE: statements. These key-value pairs will travel down to the actual source code as #define directives and can be used in the actual probe code to control it's behaviour.

| Entry                                               | Description                                                                                           |
|-----------------------------------------------------|-------------------------------------------------------------------------------------------------------|
DMCE_PROBE_DEFINE:DMCE_PROBE_NBR_TRACE_ENTRIES        |
DMCE_PROBE_DEFINE:DMCE_PROBE_NBR_OPTIONAL_ELEMENTS    |
DMCE_PROBE_DEFINE:DMCE_PROBE_OUTPUT_PATH              |
DMCE_PROBE_DEFINE:DMCE_PROBE_LOCK_DIR_ENTRY           |
DMCE_PROBE_DEFINE:DMCE_PROBE_LOCK_DIR_EXIT            |
DMCE_PROBE_DEFINE:DMCE_PROBE_TRACE_ENABLED            |
DMCE_PROBE_DEFINE:DMCE_PROBE_HANDLE_SIGNALS           |
DMCE_EDITOR                                           |
DMCE_CACHE                                            |

