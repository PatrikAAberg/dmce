.PHONY: test gcc_torture gcc_torture_vars gplusplus_torture  gplusplus_torture_vars
.DEFAULT_GOAL := test
.NOTPARALLEL:

gcc_torture:
	@test/gcc_torture/gcc_torture.sh || true

gcc_torture_vars:
	@test/gcc_torture/gcc_torture.sh 10 || true

gplusplus_torture:
	@test/gplusplus_torture/gplusplus_torture.sh || true

gplusplus_torture_vars:
	@test/gplusplus_torture/gplusplus_torture.sh 10 || true

dmce_examples:
	bash -c "cd test/dmce-examples; ./dmce-examples.sh" || true

test: gcc_torture gcc_torture_vars gplusplus_torture gplusplus_torture_vars dmce_examples
