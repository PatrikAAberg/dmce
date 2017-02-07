# dmce (did my code execute)

Code test coverage tool component for Linux. Probes c/c++ expressions added between two source code revisions. Consists of a bunch of bash and python scripts. No need to build, runs out of the box.

dmce is primarily intended for embedded systems where the level of intrusion must be kept low. Only code delta is probed and probes are lightweight!

As dmce focus on code delta coverage, test teams are kept on their toes keeping up with the latest feature development!

Ever noticed that code coverage gets less interesting the more code is added to the project? The latest additions affect test code coverage much less than the earlier ones. Code delta coverage keeps relevant!

Please note that dmce only uses clang for code insertion. Any build tool chain capable of building executables from c/c++ code can be used. 

#### Examples of use:

* Typically used in a continuous integration / continuous delivery environment 
* Patch upload test for git / gerrit / jenkins setups. Instead of getting "pass / fail", you get "pass / fail / executed"
* Identify redundant test runs to optimize lab cost
* Data source for test development / product development adherence metrics
* Why not give developers a heads up when all their latest code has ben run ok at least once in a test suite? Maybe even terminate it to free lab resources!
* What is the c code test coverage for the features added the last month?  

### Dependencies

clang 3.4

git 2.10

bash 4

python 2.7

### Download

Clone from github

    $ git clone https://github.com/patrikAAberg/dmce

### Install

Put together a default .dmceconfig file and put it in your home directory. Use this file to control dmce behaviour.

    $ cd dmce
    $ ./dmce-install

### Run

A simple example for a git named "mygit". First, clone and enter git repo: 

    $ git clone https://github.com/me/mygit
    $ cd ..
    $ cd mygit

Now, run dmce for the latest 5 commits:

    $ ../dmce/dmce-launcher -n 5 

Check what code was changed:

    $ git diff

If there were added c expressions for the latest 5 commits, the inserted DMCE probes should be visible!
Now, do whatever is needed to build. For this git it is enough to run make: 

    $ make 

If you encounter files that do not build, please relax. You can park them as excluded in the dmce.exclude file and handle them later. You can also mark certain constructions (typically some special macros or similar) using the constructs.exclude file in the same way. After editing your exceptions, re-run the launcher and repeat until no errors are reported from make.
When you are happy with your build, run the tests (for this git, make check is used) and catch the output from the dmce-probe-user.c probe:

    $ make check 2> outstderr.log 

Let the summary script print the results:

    $ ../dmce/dmce-summary outstderr.log

### Configuration

Configuration is stored in the file ".dmceconfig". If dmce finds this file in the root of the git being probed this copy will be used. If not found there, it will pick the one in the user's home directory. This way, in a multi-git project, each git can have its own dmce configuration. During installation, a default .dmceconfig will be put in the user's home directory.

#### The configurable parameters  

Location of the dmce scripts:

        DMCE_EXEC_PATH

Location of dmce temporary files:

        DMCE_WORK_PATH

Directory where dmce look for the files constructs.exclude, dmce.include and dmce.exclude:

        DMCE_CONFIG_PATH

If you want to import compiler commands, e.g. from a makefile or similar, point to your import script here:

        DMCE_CMD_LOOKUP_HOOK

Default command line parameters if not using a lookup hook:

        DMCE_DEFAULT_C_COMMAND_LINE
        DMCE_DEFAULT_CPP_COMMAND_LINE

Select what probe to use (currently 3 available):
    
        DMCE_PROBE_SOURCE

Log files will end up here:

        DMCE_LOG_FILES


### Contact

For questions, issues, pull requests, usage scenario discussions, suggestions for improvement or anything we cannot think of right now, please do not hesitate to contact us:

patrik.aberg@ericsson.com

magnus.templing@ericsson.com
