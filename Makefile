.PHONY: test gcc_torture gplusplus_torture
.DEFAULT_GOAL := test
.NOTPARALLEL:

gcc_torture:
	@test/gcc.c-torture/gcc.c-torture.sh
	@test/gcc.c-torture/gcc.c-torture.sh 5

gplusplus_torture:
	@test/g++.dg-torture/g++.dg-torture.sh
	@test/g++.dg-torture/g++.dg-torture.sh 5

test: gcc_torture gplusplus_torture
