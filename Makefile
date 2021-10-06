.PHONY:test

test:
	@test/gcc.c-torture/gcc.c-torture.sh
	@test/g++.dg-torture/g++.dg-torture.sh
