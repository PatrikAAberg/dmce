# dmce (did my code execute?)

Source code level instrumentation tool that enables dynamic code execution tracking without build tool chain dependencies.

Probes c/c++ expressions added between two git revisions. Consists of a bunch of bash and python scripts on top of clang-check and git.

Latest stable tag: v1.1.0

## Probed code example

Before dmce probing:

    int foo(int a) {

        return a + 42;
    }

    int bar(int b) {

        int c;

        c = foo(b);
        return c + 42;
    }

After dmce probing:


    int foo(int a) {

        return(DMCE_PROBE(0), a + 42);
    }

    int bar(int b) {

        int c;

        (DMCE_PROBE(1),c = foo(b));

        return(DMCE_PROBE(2), c + 42);
    }

## Dependencies

clang-check 10.0.0+

git 2.10+

bash 4+

python 3+

## How to get started

### Alternative 1: Install Using .deb package
Find the release debian package in "releases" on this page. Download it, install it and run

    $ dmce-configure-global

This will produce a .dmceconfig file at /home/$USER and a dmce configuration directory at /home/$USER/.config. Use the files in this directory to control DMCE behaviour.

### Alternative 2: Clone the git or download tarball

Clone from github

    $ git clone https://github.com/PatrikAAberg/dmce.git

or download the release tarball of choice found in "releases" to the right on this page.
Enter the dmce directory (cloned or un-tar'ed). Now run:

    $ dmce-configure-local

This will produce a .dmceconfig file which uses the dmce directory as source for all execution and configuration.


## Configuration

Valid for both alternatives above:
Configuration is stored in the file ".dmceconfig". If dmce finds this file in the root of the git being probed this copy will be used. If not found there, it will pick the one in the user's home directory (initially put there by dmce-configure-local or dmce-configure-global). This way, in a multi-git project, each git can have its own dmce configuration.

### .dmceconfig walkthrough
(showing default values written by dmce-configure-global)

#### DMCE exec path
Where DMCE finds it's executables (dmce-launcher, dmce-trace):

    DMCE_EXEC_PATH:/usr/share/dmce

#### Working directory
A lot of temporary files are being created by DMCE, this is where they end up:

    DMCE_WORK_PATH:/tmp/$USER/dmce

#### Configuration files path
A DMCE run can be configured using the files in this directory:

    DMCE_CONFIG_PATH:/home/$USER/.config/dmce
        constructs.exclude          # Regular expressions to textually filter out lines that should not be probed
        dmce.exclude                # Regular expressions used to exclude files and functions (myfile:myfunction), function can be omitted 
        dmce.include                # Regular expressions used to include files and functions (myfile:myfunction), function can be omitted
        recognizedexpressions.py    # Advanced usage: Python regexps to choose what types of expressions to probe
        cmdlookuphook.sh            # Advanced usage: This hook makes it possible to produce file-specific compiler switches (typically #ifdefs)

#### Command line lookup hook
See above.

    DMCE_CMD_LOOKUP_HOOK:/home/$USER/.config/dmce/cmdlookuphook.sh

#### Default compiler command line for c files
These compiler command line switches is passed to clang-check if no specific switches are returned from the lookup hook for a specific file

    DMCE_DEFAULT_C_COMMAND_LINE:gcc -I/usr/include -isystem /tmp/$USER/dmce/inc -I/tmp/$USER/dmce/inc

#### Default compiler command line for cpp files
Same as above but for C++ files

    DMCE_DEFAULT_CPP_COMMAND_LINE:gcc -std=c++11 -I/usr/include -isystem /tmp/$USER/dmce/inc -I/tmp/$USER/dmce/inc

#### Default compiler command line for h files
Same as above but for include files

    DMCE_DEFAULT_H_COMMAND_LINE:gcc -std=c++11 -I/usr/include -isystem /tmp/$USER/dmce/inc -I/tmp/$USER/dmce/inc

#### Number of data variables to probe
If this value is set (5 is supported by existing trace probe), DMCE will insert probes that except for the probe number also contain the last 5 declared variables available in the current scope.

    DMCE_NUM_DATA_VARS:0

#### Probe definition c file
This is the probe file. It is appended at the end of all probed files and contains code that will be exececuted every time a probe is passed.

    DMCE_PROBE_SOURCE:/usr/share/dmce/dmce-probe-user.c

#### Prologue definition c file
This is the prolouge file. It is inserted at the top of all probed files and should only contain macro and headers that makes the probe accessible in the probed file.

    DMCE_PROBE_PROLOG:/usr/share/dmce/dmce-prolog-default.c

#### Log files

    DMCE_LOG_FILES:/tmp/$USER/dmce

#### git diff algorithm
When dmce is searching for added expressions between two git revisions it uses git diff, which comes with several different diff algorithms. Somewhat different behaviours can be noticed using different ones.

    DMCE_GIT_DIFF_ALGORITHM:histogram

    Available algorithms:
        myers
        histogram
        minimal
        patience
