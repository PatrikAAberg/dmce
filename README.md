<img src="https://github.com/PatrikAAberg/dmce/assets/22773714/d6224f16-d9d3-4d42-bbe6-895805b20dfe" width=40% height=40%>

# DMCE (Did My Code Execute?)

Source code level instrumentation tool that enables dynamic code execution tracking *with minimal HW or build tool chain dependencies*.

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

## Contents

#### [- Dependencies](#dependencies) 
#### [- Install and setup](#install-and-setup) 
#### [- A simple probing workflow example](#a-simple-probing-workflow-example) 
#### [- Trace](#trace) 
#### [- Trace GUI](https://github.com/PatrikAAberg/dmce-gui)
#### [- Code execution pattern diff](#code-execution-pattern-diff) 
#### [- Patch coverage](#patch-code-coverage) 
#### [- Traditional code coverage](#traditional-code-coverage) 
#### [- Heatmaps and code execution patterns](#heatmaps-and-code-execution-patterns) 
#### [- Use the trace-mc profile for data code coverage](#use-the-trace-mc-profile-for-data-code-coverage) 
#### [- Provoke race conditions](#provoke-race-conditions) 
#### [- DMCE command summary](#dmce-command-summary)
#### [- Probing pass configuration](#probing-pass-configuration)
#### [- Execution pass configuration](#execution-pass-configuration)
#### [- DMCE API functions](#dmce-api-functions)
#### [- FAQ](#faq)

## Dependencies

git 2.10+

bash 4+

python 3.7+

clang-tools

Normally works with clang-check (llvm) versions 10+

Currently recommended clang-check (llvm) version: 17 

## Install and setup

To build an installable DMCE .deb package from latest source:

    $ git clone https://github.com/PatrikAAberg/dmce.git
    $ cd dmce
    $ ./build-pkg

To install on Ubuntu / Debian:

    $ dpkg -i dmce-X.Y.Z.deb    # To uninstall: $ dpkg -r dmce
    $ dmce-setup

Other distros:

    $ ./build-pkg --help
    usage: build-pkg [bz2|deb|gz|rpm|xz]

Latest stable tag: (to be updated to v2.0.0)

The above will install the neccesary executables and create a default .dmceconfig file and a .config/dmce directory at $HOME. Modify the files in this directory to directly control DMCE behaviour OR use the "dmce-set-profile" utility AND/OR use override switches available for the (dmce) tool itself. The first two will be persistent, the last one will be be used one-time only.

## A simple probing workflow example

This is a basic example just showing how DMCE probes are inserted without changing SW behaviour with respect to the original function.

    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    $ cd dmce-examples

Modify the DMCE configuration using the "dmce-set-profile" utility to use a printf probe. We want to include the "simple" directory and exclude the "simplecrash" directory:

    $ dmce-set-profile -i simple -e simplecrash printf

Run DMCE for all commits in the git, making it probe everything:

    $ dmce

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

## Code execution pattern diff

![dmce-diff](https://github.com/PatrikAAberg/dmce/assets/22773714/84a81ea3-e440-479d-939b-c4674d06adbe)

A DMCE code execution pattern (generated using the "heatmap" profile) consists of an array of counters, each counter representing the number of times each probe has been hit. During a debug session, it can be quite valuable to compare patterns for e.g. passed / failed runs:

    $ cd dmce-examples/diff
    $ dmce && ./build && ./diffthis
    $ cp /tmp/$USER/dmce/dmcebuffer.bin buf1
    $ rm /tmp/$USER/dmce/dmcebuffer.bin
    $ ./diffthis foo
    $ cp /tmp/$USER/dmce/dmcebuffer.bin buf2
    $ dmce-diff buf1,buf2 /tmp/$USER/dmce/dmce-examples/probe-references.log ../

## Patch code coverage

This was the original use case for DMCE. How to check delta (between two git revisions) code coverage in gits without messing with their respective build or test systems? See example below.

    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    $ cd dmce-examples

Set up DMCE to do coverage, including only the "patchcov" directory:

    $ dmce-set-profile coverage -i patchcov

Apply the patch in the patchcov dir:

    $ git apply patchcov/000-patchcov.patch

Probe the untracked and modified files, nothing more:

    $ dmce -n 1

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

## Traditional code coverage

DMCE can be used as a traditional code coverage tool. This is done by using the patch coverage flow in the previous section, selecting the delta as the entire git history:

    $ dmce-set-profile coverage
    $ dmce
    $ # execute program here
    $ dmce-summary-bin -v /tmp/$USER/dmce/dmcebuffer.bin /tmp/$USER/dmce/dmce-examples/probe-references-original.log

## Heatmaps and code execution patterns

Using the heatmap profile, in the same way as when doing code coverage, heatmaps (also known as code execution pattern) can be generated.:

    $ dmce-set-profile heatmap
    $ dmce
    $ # execute program here
    $ dmce-summary-bin -v /tmp/$USER/dmce/dmcebuffer.bin /tmp/$USER/dmce/dmce-examples/probe-references-original.log

## Use the trace-mc profile for data code coverage

Using the trace-mc profile, DMCE can provide a view of frequently visited parts of your code as well as provide a form of data code coverage for your tests. To enable these features, simply use the --sort switch together with the dmce-trace command. Current available options for --sort are:

* heat        - What parts of your code are executed most frequently
* uniq        - How many of each unique variable content combination exist for each executed part of your code 
* collapse    - How many different variable content combinations exist for each executed part of our code

A simple example for the "heat" option:

    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    $ cd dmce-examples

Use the trace-mc profile, only include the "loops" folder:

    $ dmce-set-profile trace -i loops

Run DMCE for all commits in the git, making it probe everything:

    $ dmce

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
    $ dmce
    $ cd simple && ./build && ./simple

## DMCE command summary

For each command, please see their respective --help for further details.

| Command           | Description                                                                                                   |
|-------------------|---------------------------------------------------------------------------------------------------------------|
| dmce-setup        | Create a .dmceconfig file and a config directory in $HOME and $HOME/.config                                   |
| dmce-set-profile  | Config file helper utility: Choose one of pre-defined configurations, add filters and change some behaviours  |
| dmce              | Insert probes in current git directory                                                                        |
| dmce-stats        | Get some stats (how many inserted probes etc.) from a probed git                                              |
| dmce-summary-bin  | Get a coverage / heatmap report (using the "coverage" profile)                                                |
| dmce-trace        | Generate a textual trace output (using the "trace-mc" or "trace" profile)                                     |
| dmce-trace-viewer | Launch an interactive trace viewer (using the "trace-mc" or "trace" profile)                                  |
| dmce-diff         | Diff tool for comparing code execution pattern buffers generated with the heatmap profile                     |

## Entries in .dmceconfig

### Probing pass configuration
Configuration is stored in the file ".dmceconfig". If dmce finds this file in the root of the git being probed this copy will be used. If not found there, it will pick the one in the user's home directory (initially put there by dmce-setup, and later modified by dmce-set-profile).

| Entry                            | Description                                                                                           |
|----------------------------------|-------------------------------------------------------------------------------------------------------|
| DMCE_MEMORY_LIMIT                | How much memory (in percent) DMCE is allowed to use during probing pass                                                                                                       |
| DMCE_EXEC_PATH                   | Where DMCE finds it's internal executables                                                            |
| DMCE_WORK_PATH                   | A lot of temporary files are being created by DMCE, this is where they end up                         |
| DMCE_CONFIG_PATH                 | A DMCE run can uses configuration coming from files in this directory                                 |
| DMCE_CMD_LOOKUP_HOOK             | This hook makes it possible to produce file-specific compile command lines                            |
| DMCE_DEFAULT_C_COMMAND_LINE      | Default compile command line for C files                                                              |
| DMCE_DEFAULT_CPP_COMMAND_LINE    | Default compile command line for C++ files                                                            |
| DMCE_DEFAULT_H_COMMAND_LINE      | Default compile command line for include files                                                        |
| DMCE_NUM_DATA_VARS               | Some probes (trace) needs to know how many variables to store. Needs to be the same as DMCE_PROBE_DEFINE:DMCE_PROBE_NBR_OPTIONAL_ELEMENTS |
| DMCE_ALLOW_DEREFERENCES          | When fecthing variables, determines if de-referenced pointer values should be picked up               |
| DMCE_PROBE_SOURCE                | The source file containing the probe entry                                                            |
| DMCE_PROBE_PROLOG                | The source file containing anything the probe needs to be defined before the probed file              |
| DMCE_POST_HOOK                   | An executable that is run after the probing pass                                                      |
| DMCE_SYS_INCLUDES                | Use host system include files or not                                                                  |
| DMCE_PROBE_TEMPLATES             | Probe C++ Templates or not                                                                            |
| DMCE_FIX_NULLPTR                 | Try to replace "return 0" with "return nullptr" for functions returning a pointer or not              |
| DMCE_TOP_LEVEL_VARS              | Fetch contents of top level variables or not                                                          |
| DMCE_GIT_DIFF_ALGORITHM          | Select what git diff algorithm should be used when searching for code additions                       |
| DMCE_EDITOR                      | Utilities (currently the terminal UI) use this to pick source code editor                             |
| DMCE_CACHE                       | Experimental: Enable DMCE caches for speeding up consecutive runs                                     |

### Execution pass configuration
It is possible to pass information to the running code by using DMCE_PROBE_DEFINE: statements. These key-value pairs will travel down to the actual source code as #define directives and can be used in the actual probe code to control it's behaviour.

| Entry                                                 | Description                                                                                               |
|-------------------------------------------------------|-----------------------------------------------------------------------------------------------------------|
| DMCE_PROBE_DEFINE:DMCE_PROBE_NBR_TRACE_ENTRIES        | Used by trace probes: How many trace entries per buffer (multiple with number of used cores for trace-mc) |
| DMCE_PROBE_DEFINE:DMCE_PROBE_NBR_OPTIONAL_ELEMENTS    | Used by trace probes: How many optional elements within each trace entry                                  |
| DMCE_PROBE_DEFINE:DMCE_PROBE_OUTPUT_PATH              | Where probes should put any out files                                                                     |
| DMCE_PROBE_DEFINE:DMCE_PROBE_LOCK_DIR_ENTRY           | If needed by the probe: Path to where to put the mkdir lock for init code                                 |
| DMCE_PROBE_DEFINE:DMCE_PROBE_LOCK_DIR_EXIT            | If needed by the probe: Path to where to put the mkdir lock for exit code                                 |
| DMCE_PROBE_DEFINE:DMCE_PROBE_TRACE_ENABLED            | Decides if trace should be enabled from start of the program or not                                       |
| DMCE_PROBE_DEFINE:DMCE_PROBE_HANDLE_SIGNALS           | Probes can use this to know if they should register a signal handler                                      |

### DMCE API functions

| Name                                                        | Description                                                                 |
|-------------------------------------------------------------|-----------------------------------------------------------------------------|
| DMCE_BP()                                                   | Raise a SIGTRAP signal, making the process stop and produce a dmce trace    |
| DMCE_HEXDUMP(uint64_t hdnum, void* p, uint64_t size)        | Insert a hexdump into the trace buffer. hdnum can contain an arbitrary value for identification at later stages |
| void DMCE_PRINTF(const char* fmt, ...)                      | Insert a formatted printf like text into the trace buffer                   |

### FAQ

To be updated
