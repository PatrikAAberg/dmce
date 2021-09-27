# dmce (did my code execute?)

Source code level instrumentation tool that enables dynamic code execution tracking without build tool chain dependencies.

Probes c/c++ expressions added between two git revisions. Consists of a bunch of bash and python scripts on top of clang-check and git.

Latest stable tag: v1.0.0

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
    $ ./dmce-configure-local

### Run

A simple example for a git named "mygit". First, clone and enter git repo: 

    $ git clone https://github.com/me/mygit
    $ cd ..
    $ cd mygit

Now, run dmce for the latest 5 commits:

    $ ../dmce/dmce-launcher -n 5

Check what code was changed:

    $ git diff

If there were added c expressions for the latest 5 commits, the inserted DMCE probes should be visible.
Now, do whatever is needed to build. For this git it is enough to run make:

    $ make


    $ make check 2> outstderr.log

Let the summary script print the results:

    $ ../dmce/dmce-summary outstderr.log

### Configuration

Configuration is stored in the file ".dmceconfig". If dmce finds this file in the root of the git being probed this copy will be used. If not found there, it will pick the one in the user's home directory. This way, in a multi-git project, each git can have its own dmce configuration. During installation, a default .dmceconfig will be put in the user's home directory.

