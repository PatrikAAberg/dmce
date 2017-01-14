# dmce (did my code execute)

Code test coverage tool component for Linux. Probes c expressions added between two source code revisions. Consists of a bunch of bash and python scripts. No need to build, runs out of the box.

dmce is primarily intended for embedded systems where the level of intrusion must be kept low. 

dmce focus on delta code coverage, which means that test teams are kept on their toes keeping up with the latest feature development!

#### Examples of use:

* Typically used in a continious integration / continious delivery environment 
* Patch upload test for git / gerrit / jenkins setups. Instead of getting "pass/fail", you can now get "pass/fail/executed"
* Identify redundant test runs to optimize lab usage cost
* Data source for test development / product development adherence metrics
* What is the c code test coverage for the patches added the last month?  

### Dependencies

clang 3.4-8

git 2.10+

bash

python 2

### Download

Clone from github

    $ git clone https://github.com/patrikAAberg/dmce

### Install

Put together a default .dmceconfig file and put it in your home directory. Use this file to control dmce behaviour.

    $ cd dmce
    $ ./dmce-install

### Run

A simple example for the git "mygit" with the test suite "mytest.sh"

    $ git clone https://github.com/me/mygit
    $ cd ..
    $ cd mygit
    $ ../dmce/dmce-launcher -n 5 
    $ mytest.sh 2> outstderr.log 
    $ ../dmce/dmce-summary outstderr.log

The above do the following:

1. Clone the git to be played around with, in this case "mygit".
2. Put together a default .dmceconfig file and put it in your home directory. Use this file to control dmce behaviour.
3. Probe the 5 latest commits in "mygit"
4. Run a module test called "mytest.sh" using stderr to catch the output from the dmce-probe-user.c probe.
5. Summarizes the results.


### Contact

For questions, issues, usage scenario discussions, suggestions for improvement or anything we cannot think of right now, please do not hesitate to contact us:

patrik.aberg@ericsson.com

magnus.templing@ericsson.com


