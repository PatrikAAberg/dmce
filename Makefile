.PHONY: test gcc_torture gcc_torture_vars gplusplus_torture  gplusplus_torture_vars
.DEFAULT_GOAL := test
.NOTPARALLEL:

gcc_torture:
	@test/gcc.c-torture/gcc.c-torture.sh || true

gcc_torture_vars:
	@test/gcc.c-torture/gcc.c-torture.sh 5 || true

gplusplus_torture:
	@test/g++.dg-torture/g++.dg-torture.sh || true

gplusplus_torture_vars:
	@test/g++.dg-torture/g++.dg-torture.sh 5 || true

test: gcc_torture gcc_torture_vars gplusplus_torture gplusplus_torture_vars
