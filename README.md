# dmce (did my code execute?)

Source code level instrumentation tool that enables dynamic code execution tracking without build tool chain dependencies.

Probes c/c++ expressions added between two git revisions. Consists of a bunch of bash and python scripts on top of clang-check and git.

#### Examples of use

* Typically used in a CI/CD pipeline, but due to it's simplicity it is also useful on the developer's prompt
* Patch upload test for git / gerrit / jenkins setups. Instead of getting "pass / fail", you get "pass / fail / executed"
* Identify redundant test runs to optimize lab cost
* Data source for test development / product development adherence metrics
* Data source for delta code coverage metrics
* Enables massive, parallel printf()-debugging with as low intrusion as you can make your probe (probes are pluggable)

### Probed code example

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

### Reference project
Ericsson Research use dmce with Travis CI within the Calvin project:

https://github.com/EricssonResearch/calvin-constrained

### Dependencies

clang-check 10.0.0+

git 2.10+

bash 4+

python 3+

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

If you encounter files that do not build, relax. You can park them as excluded in the dmce.exclude file and handle them later. You can also mark certain constructions (typically some special macros or similar) using the constructs.exclude file in the same way. After editing your exceptions, re-run the launcher and repeat until no errors are reported from make.
When you are happy with your build, run the tests (for this git, make check is used) and catch the output from the dmce-probe-user.c probe:

    $ make check 2> outstderr.log

Let the summary script print the results:

    $ ../dmce/dmce-summary outstderr.log

A comment on the summary: Since probes can be any C function, dumping a piece of memory works as well. There are some examples of those kinds of probes included.

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
        DMCE_DEFAULT_H_COMMAND_LINE

Select what probe to use (use one of the pre-made ones or create your own):

        DMCE_PROBE_SOURCE

Select probe prolog (the default one should be ok for most cases)

        DMCE_PROBE_PROLOG

Log files will end up here:

        DMCE_LOG_FILES

