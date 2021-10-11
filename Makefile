.PHONY: test gcc_torture gplusplus_torture
.DEFAULT_GOAL := test
.NOTPARALLEL:

gcc_torture:
	@test/gcc.c-torture/gcc.c-torture.sh

gplusplus_torture:
	@test/g++.dg-torture/g++.dg-torture.sh

test: gcc_torture gplusplus_torture
