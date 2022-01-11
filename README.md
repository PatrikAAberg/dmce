# dmce (did my code execute?)

Source code level instrumentation tool that enables dynamic code execution tracking *without build tool chain dependencies*.

Probes c/c++ expressions added between two git revisions. Consists of a bunch of bash and python scripts on top of clang-check and git.

Latest stable tag: v1.3.1

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
Find the latest released debian package in "releases" to the right on this page. Download it, install and set up dmce:

    $ dpkg -i dmce-X.Y-Z.deb    # To uninstall: $ dpkg -r dmce

    $ dmce-setup

This will produce a .dmceconfig file at /home/$USER and a dmce configuration directory at /home/$USER/.config. Modify the files in this directory to directly control DMCE behaviour OR use the "dmce-set-profile" tool which has some pre-set profiles that handle common use-cases.

### Alternative 2: Clone the git or download tarball

Clone from github (make sure to checkout latest stable tag)

    $ git clone https://github.com/PatrikAAberg/dmce.git

or download the release tarball of choice found in "releases" to the right on this page.
Enter the dmce directory (cloned or un-tar'ed) and run the local configure script:

    $ cd dmce

    $ ./dmce-configure-local

This will produce a .dmceconfig file in the home directory which uses the dmce directory as source for all execution and configuration. Any call to dmce executables in the following examples need to be prepended by the path to the dmce directory.

#### Please note! The examples below assume an alt. 1 installation above. If you choose alt. 2, you can use the -p flag for "dmce-set-profile" to not tamper with the paths to the dmce git, and the -d switch to point to the dmce git clone, using it as config directory.

## Example 1: A simple, general example of probing

This is a basic example just showing how DMCE probes are inserted without changing SW behaviour with respect to the original function.
Please note that this walkthrough assumes you use the install alternative 1 above. Let's go: Clone the dmce-examples git and enter the directory:

    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    $ cd dmce-examples

Modify the dmce configuration using the "dmce-set-profile tool" to use a printf probe. We want to include the "simple" directory and exclude the "simplecrash" directory:

    $ dmce-set-profile printf -i simple -e simplecrash

Run dmce for more commits than are actually in the git, making it probe everything:

    $ dmce-launcher -n 10000 --progress

Check the diff. You should be able to see the inserted dmce probes.

    $ git diff

Go into the simple example folder, build the executable and run it.

    $ cd simple && ./build && ./simple

It builds and runs. Nothing functional-wise is changed,  but we have inserted hooks at all do-something-expressions. Using dmce-probe-XYZ.c files we can now extract information from code execution without tampering with build chains or using target- or OS specifics. In this example, we have used a probe that simply prints to stderr the first time that position in the code is passed, and keep silent after that.

Of course you want to be able to go back to a non-probed state. You do this using the -c switch in the git root:

    $ cd ..
    $ dmce-launcher -c
    $ git diff

The probes are now removed. A note: -n 1 means "probe everyting untracked and/or modified". -n 2 means "probe everything untracked, and/or modified and the last commit". Increasing the number will increase the number of commits backwards in time. Please run dmce-launcher --help for additional ways of stating revision delta. In this example, we want to probe everything, so a larger number (10000) than the number of available commits is used.

## Example 2: How to use dmce trace

DMCE can be used as a trace tool. The following example shows how to find a null-pointer bug in an example program.
Please note that this walkthrough assumes you use the install alternative 1 above. Let's go: Clone the dmce-examples git and enter the directory:

    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    $ cd dmce-examples

Modify the dmce configuration to use a trace probe, including only the "simplecrash" folder:

    $ dmce-set-profile trace -i simplecrash

Run dmce for more commits than are actually in the git, making it probe everything:

    $ dmce-launcher -n 10000 --progress

Go into the simplecrash example folder, build the executable and run it.

    $ cd simplecrash && ./build && ./simplecrash
    $ cd -

It crashes! Let's find out why. Step up to the git root again and run dmce-trace. Note: If you have not already done so, you need to install the python3 modules colorama and numpy:

    $ pip3 install colorama numpy

    $ dmce-trace --numvars 5 --sourcewidth 80 -A 3 -B 2 -t --hl /tmp/${USER}/dmce/dmcebuffer.bin /tmp/${USER}/dmce/dmce-examples/probe-references.log $(pwd)

This line deserves a bit of explanation. The standard trace probe uses maximum of 5 variables. We want to use 80 characters for the source view, view 2 lines before each executed line and 3 after as well as enable timestamps and highlight each trace entry. The last three parameters are: The raw buffer file produced by the dmce trace probe, the probe references file produced in the probing stage and last but not least the path to the root of the git repo. Please note that the path where the raw trace file end up is decided by the probe through a DMCE_PROBE_DEFINE in the ".dmceconfig" file.

For larger traces than this one, something to try out is to pipe the results to less for easy view and search, like this:

    $ dmce-trace --numvars 5 --sourcewidth 80 -A 3 -B 2 -t --hl /tmp/${USER}/dmce/dmcebuffer.bin /tmp/${USER}/dmce/dmce-examples/probe-references.log $(pwd) | less -r

That's it! You should now be able to see the null-pointer bug at the end of execution.

## Example 3: Patch code coverage

This was the original use case for dmce. How to check delta (between two git revisions) code coverage in gits without messing with their respective build or test systems? An example of how this can be done is shown below.
Please note that this walkthrough assumes you use the install alternative 1 above. Let's go: Clone the dmce-examples git and enter the directory:

    $ git clone https://github.com/PatrikAAberg/dmce-examples.git
    $ cd dmce-examples

Set up dmce to do coverage, including only the "patchcov" directory:

    $ dmce-set-profile coverage -i patchcov

Apply the patch in the patchcov dir:

    $ pushd patchcov
    $ git apply 000-patchcov.patch
    $ popd

Probe the untracked and modified files, nothing more:

    $ dmce-launcher -n 1 --progress

Check that the patch was probed:

    $ git diff

Note, doxygen annotations are treated as code. Changing a doxygen comments may result in that following source code declaration gets instrumented.

Go into the patchcov directory again to build and run the tests. Note! Since the probe being used here can collect data from several executables, make sure to remove any old /tmp/$USER/dmce/dmcebuffer.bin file if it is not the intention to collect several runs in the same file:

    $ rm -f /tmp/$USER/dmce/dmcebuffer.bin
    $ cd patchcov
    $ ./build && ./test-patchcov

Use dmce summary to display the results. For this example, we use a binary format probe, so the same goes for the summary:

    $ dmce-summary-bin -v /tmp/$USER/dmce/dmcebuffer.bin /tmp/$USER/dmce/dmce-examples/probe-references-original.log

The probe that was set up by "dmce-set-profile coverage" writes its output to /tmp/$USER/dmce/dmcebuffer.bin, so that's where we pick it up. Also note that the probe reference file used here is "probe-references-original.log" as opposed to "probe-references.log" that was used for the trace example. This is becasue for coverage, you want the line numbers coming from the original source code files and not the probed ones.
Anyway, the test passes with success! But wait, we also see that only half of the added probes were executed. And it could have been much worse...

## Mandatory entries in .dmceconfig

Valid for both alternatives above:
Configuration is stored in the file ".dmceconfig". If dmce finds this file in the root of the git being probed this copy will be used. If not found there, it will pick the one in the user's home directory (initially put there by dmce-configure-local or dmce-setup). This way, in a multi-git project, each git can have its own dmce configuration.

### .dmceconfig walkthrough
(showing default values written by dmce-setup)

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

### Optional entries in .dmceconfig

#### Passing defines to dmce probes
Sometimes it is useful to be able to pass custom information from the .dmceconfig file to the currently used probe. Below is an example:

    DMCE_PROBE_DEFINE:FOO
    DMCE_PROBE_DEFINE:BAR (42)

These lines will insert the following after the probed c-file but before the probe code:

    #define FOO
    #define BAR (42)

#### Changing the type of traced variables
The dmce trace probe normally cast all variables to uint64_t. However, a custom probe might want to use a different data type. Below is an example of how to change type to unsigned long:

    DMCE_TRACE_VAR_TYPE:unsigned long

