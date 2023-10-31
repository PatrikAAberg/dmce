#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
#
# MIT License
#
# Copyright (c) 2023 Ericsson
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is furnished
# to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice (including the next
# paragraph) shall be included in all copies or substantial portions of the
# Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS
# OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
# OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

set -e

_name="dmce-examples"

# mode 0 = compare/verify git diffs after each test vs. reference diff files within 'dmce-examples.tar.xz'
# mode 1 = create a new 'dmce-examples.tar.xz' file - no verfication is performed in this mode
_mode=0

# reference diff files (within 'dmce-examples.tar.xz') are dependent on LLVM version
_llvm_major_version=17

# use a fixed revision
_url="https://github.com/PatrikAAberg/dmce-examples"
_sha1="098bec3a53cc7d71388bca60673ca5f67bc2e505"

# directories
_dir_tmp="/tmp/${USER:?}"
_dir_dmce="${_dir_tmp:?}/dmce"
_dir_tst="${_dir_tmp:?}/${_name:?}"
_dir_ref="${_dir_tst:?}/ref"
_dir_src="${_dir_tst:?}/${_name:?}"

function stash_and_checkout() {
	git stash -q
	git checkout -q "${_sha1:?}"
	git clean -dfxq
	git worktree prune
}

function cleanup() {
	if [ "${?}" -eq 42 ]; then
		stash_and_checkout
		set +x
		echo "OK | ${i} test(s) | $((SECONDS - s)) seconds"
	else
		echo "NOK | ${i} test(s) | $((SECONDS - s)) seconds"
	fi
}

function pre() {
	rm -rf "${_dir_dmce:?}"/* "${_dir_tst:?}"/dmce-examples-*
	stash_and_checkout
	${dmce} -c
}

function verify() {
	local f

	if [ ${#} -eq 0 ]; then
		f="${PWD}/${FUNCNAME[1]}.diff"
	else
		f="${PWD}/${1}"
	fi
	git diff | sed -e "/^index /d" -e "s,/tmp/${USER:?}/dmce,/tmp/USER/dmce,g" > "${f}"

	if [ "${_mode:?}" -eq 0 ]; then
		if ! diff -q "${f}" "${_dir_ref:?}/${f##*/}"; then
			exit 1
		fi
	else
		cp -a "${f}" "${_dir_ref:?}/${f##*/}"
	fi
}

function init() {
	local c
	local d
	local deps
	local llvm_ver

	if [ ! -s "${_name}.tar.xz" ]; then
		echo "error: run from the 'test/${_name:?}/' directory" 1>&2
		exit 1
	fi

	deps+=" clang-check"
	deps+=" dmce"
	deps+=" dmce-set-profile"
	deps+=" dmce-setup"
	deps+=" dmce-summary-bin"
	deps+=" dmce-trace"
	deps+=" gcc"
	deps+=" git"
	deps+=" xz"

	for c in ${deps}; do
		if ! command -v "${c}" >/dev/null; then
			exit 1
		fi
	done

	declare -A -g test_desc
	for c in $(list_tests); do
		test_desc[$c]=$(grep -B1 "^function $c()" dmce-examples.sh | \
			grep -v ^function | \
			sed -e 's,^# ,,g')
	done

	mkdir -p "${_dir_ref}"
	if [ "${_mode:?}" -eq 0 ]; then
		llvm_ver=$(clang-check --version | grep -o 'LLVM.*' | grep -o '[0-9].*' | cut -d'.' -f1)
		if [ "${llvm_ver}" != "${_llvm_major_version:?}" ]; then
			exit 1
		fi

		d=${PWD}
		(cd "${_dir_ref}"; tar xf "${d}"/"${_name:?}".tar.xz;)
	else
		rm -rf "${_dir_ref:?}"/*
	fi

	if [ ! -s "${_dir_src}"/.git ]; then
		git clone "${_url:?}" "${_dir_src}"
	fi
	cd "${_dir_src}"
	stash_and_checkout
	trap cleanup EXIT

	dmce-setup "${_dir_tst}"
	dmce-set-profile \
		--configdir "${_dir_tst}"/.config/dmce \
		--file "${_dir_tst}"/.dmceconfig \
		--keeppaths \
		-E $((1024 * 64)) \
		trace-mc

	dmce="dmce -j $(getconf _NPROCESSORS_ONLN) --file ${_dir_tst}/.dmceconfig"
}

function list_tests() {
	compgen -A function | grep '^t[0-9]\+' | sort -V
}

function test_description() {
	if [ "${test_desc[$t]}" != "" ]; then
		echo "$t: ${test_desc[$t]}"
	else
		echo "$t: FIXME: add description"
	fi
}

function main() {
	local a="${PWD}"
	local i=0
	local s=${SECONDS}
	local t

	init

	if [ ${#} -eq 0 ]; then
		for t in $(list_tests); do
			test_description
			"${t}"
			i=$((i + 1))
			echo
		done
	else
		for t in "${@}"; do
			test_description
			"${t}"
			i=$((i + 1))
			echo
		done
	fi

	if [ ${#} -eq 0 ] && [ ${_mode:?} -eq 1 ]; then
		(
			cd "${_dir_ref}"
			tar --owner=0 --group=0 -cvJf "${a}"/"${_name:?}".tar.xz -- *.diff
		)
	fi

	exit 42
}

# exercise the --include option | profile: coverage
function t0() {
	pre

	${dmce} \
		--include main.c \
		--profile coverage \
		-v
	verify
	grep -q '^main.c$' "${_dir_dmce}"/"${_name:?}"/config/dmce.include
}

# make sure that one untracked file is instrumented | profile: coverage
function t1() {
	pre

	echo 'int main(){int i; i=42;}' > a.c
	${dmce} \
		-n 1 \
		--profile coverage
	grep -q '^int main.*DMCE_PROBE' a.c
	rm a.c
}

# exercise the --head option | profile: coverage
function t2() {
	pre

	${dmce} \
		--all \
		--head HEAD~10 \
		--profile coverage
	verify
	stash_and_checkout
}

# exercise the -a/--all option | profile: coverage
function t3() {
	pre

	${dmce} \
		--all \
		--profile coverage
	verify
	${dmce} \
		-a \
		--profile coverage
	verify
}

# exercise the --version and --help options | profile: coverage
function t4() {
	pre

	${dmce} --version
	${dmce} --help || true
}

# exercise the -v/--verbose option | profile: coverage
function t5() {
	pre

	${dmce} \
		--profile coverage \
		-v
	verify
	${dmce} -c
	${dmce} \
		--profile coverage \
		--verbose
	verify
}

# exercise the -n option | profile: coverage
function t6() {
	local i

	for i in $(seq 1 "$(git log --oneline | wc -l)"); do
		pre
		${dmce} \
			-n "${i}" \
			--profile coverage || true
		verify "${FUNCNAME[0]}.${i}.diff"
	done
}

# conflicting options
function t7() {
	pre

	if dmce --include main.c --exclude main.c; then
		exit 1
	elif dmce -d 52000; then
		exit 1
	elif dmce -f /dev/null; then
		exit 1
	fi
}

# untracked and constructs | profile: coverage
function t8() {
	pre

	echo 'int main(){int i; i=42;}' > a.c
	${dmce} \
		--constructs i \
		-n 1 \
		--profile coverage
	if grep -q '^int main.*DMCE_PROBE' a.c; then
		exit 1
	fi
	rm a.c
}

# exercise the coverage probe | profile: coverage
function t9() {
	pre

	${dmce} \
		--include simple/main.c,simple/simple.c \
		--profile coverage \
		-v
	verify
	(
		cd simple
		./build
		./simple
	)
	dmce-summary-bin \
		-v \
		"${_dir_dmce}"/dmcebuffer.bin \
		"${_dir_dmce}"/"${_name:?}"/probe-references.log | \
		tee "${_dir_tst}/${FUNCNAME[0]}.log"
	grep 'Probes executed:5/5' "${_dir_tst}/${FUNCNAME[0]}.log"
}

# exercise the heatmap probe | profile: heatmap
function t10() {
	pre

	${dmce} \
		--include simple/main.c,simple/simple.c \
		--profile heatmap \
		-v
	verify
	(
		cd simple
		./build
		./simple
	)
	dmce-summary-bin \
		-v \
		"${_dir_dmce}"/dmcebuffer.bin \
		"${_dir_dmce}"/"${_name:?}"/probe-references.log | \
		tee "${_dir_tst}/${FUNCNAME[0]}.log"
	grep 'Probes executed:5/5' "${_dir_tst}/${FUNCNAME[0]}.log"
}

function dmce_trace_helper() {
	dmce-trace \
		"$(find "${_dir_dmce}" -maxdepth 1 -type f -name 'dmcebuffer*' | grep -v info$)" \
		"${_dir_dmce}"/"${_name:?}"/probe-references.log \
		"${PWD}"
}

# exercise the trace-mc probe | profile: trace-mc
function t11() {
	pre

	${dmce} \
		--include simple/main.c,simple/simple.c \
		--profile trace-mc \
		-v
	verify
	(
		cd simple
		./build
		./simple
	)
	dmce_trace_helper
}

# exercise the trace-mc probe together with a threaded program | profile: trace-mc
function t12() {
	pre

	${dmce} \
		--include 'threads/.*' \
		--profile trace-mc \
		-v
	verify
	(
		cd threads
		gcc -o threads -pthread main.c
		./threads
	)
	dmce_trace_helper
}

# exercise the trace-mc probe together with a threaded program | profile: trace-mc
function t13() {
	pre

	${dmce} \
		--include 'threads/.*' \
		--profile trace-mc \
		-v
	verify
	(
		cd threads
		gcc -o trace-threads -pthread trace_threads.c
		./trace-threads || true
	)
	dmce_trace_helper
}

# exercise the trace-mc probe together with a threaded program - hexdump version | profile: trace-mc
function t14() {
	pre

	${dmce} \
		--include 'threads/.*' \
		--profile trace-mc \
		-v
	verify
	(
		cd threads
		gcc -o trace-threads-hexdump -pthread trace_threads_hexdump.c
		./trace-threads-hexdump || true
	)
	dmce_trace_helper
}

# exercise the --offset option | profile: trace-mc
function t15() {
	local a=${RANDOM}
	local d="${_dir_tst:?}"/"${_name:?}"-"${a}"

	pre

	git worktree add -q "${d}"
	${dmce} \
		--profile trace-mc \
		-v
	verify "${FUNCNAME[0]}.0.diff"
	${dmce} -c
	(
		cd "${d}"
		${dmce} \
			--offset=100000 \
			--profile trace-mc \
			-v
		verify "${FUNCNAME[0]}.1.diff"
	)
	grep ^100000 "${_dir_dmce}"/"${_name:?}"-"${a}"/probe-references.log
	grep -r 'DMCE_PROBE.*\(100000\)' "${d}"
}

main "${@}"
