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

_name="unittest"

# mode 0 = compare/verify git diffs after each test vs. reference diff files within 'unittest.tar.xz'
# mode 1 = create a new 'unittest.tar.xz' file - no verfication is performed in this mode
_mode=0

# reference diff files (within 'unittest.tar.xz') are dependent on LLVM version
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
		echo "OK | ${i} test(s) | $((SECONDS - s)) seconds"
		exit 0
	else
		find "${_dir_tst:?}"/ -maxdepth 1 -name '*.log' -print -exec cat {} \;
		echo "NOK | ${i} test(s) | $((SECONDS - s)) seconds"
	fi
}

function pre() {
	cd "${_dir_src:?}"
	t_log="${_dir_tst:?}/${FUNCNAME[1]}.log"
	rm -rf \
		"${_dir_tst:?}"/*.log \
		"${_dir_tst:?}"/dmce-examples-*
	stash_and_checkout
	dmce-setup "${_dir_tst:?}" > /dev/null
	_dir_dmce=$( \
		grep ^DMCE_WORK_PATH: "${_dir_tst:?}"/.dmceconfig | \
		cut -d: -f2)
	rm -rf \
		"${_dir_dmce:?}"/*
	# shellcheck disable=SC2086
	dmce-set-profile ${dmce_set_profile_opts:?} trace-mc
	${dmce:?} -c &> /dev/null
}

function verify() {
	local f

	if [ ${#} -eq 0 ]; then
		f="${PWD}/${FUNCNAME[1]}.diff"
	else
		f="${PWD}/${1}"
	fi
	git diff | \
		sed \
		-e "/^index /d" \
		-e "s,/tmp/${USER:?}/dmce,/tmp/USER/dmce,g" > "${f}"

	if [ "${_mode:?}" -eq 0 ] && ! diff "${f}" "${_dir_ref:?}/${f##*/}"; then
		exit 1
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
			echo "error: command '${c}' not found" 1>&2
			exit 1
		fi
	done

	declare -A -g test_desc
	for c in $(list_tests); do
		test_desc[${c}]=$(grep -B1 "^function ${c}()" unittest.sh | \
			grep -v ^function | \
			sed -e 's,^# ,,g')
	done

	mkdir -p "${_dir_ref:?}"
	if [ "${_mode:?}" -eq 0 ]; then
		llvm_ver=$(clang-check --version | grep -o 'LLVM.*' | grep -o '[0-9].*' | cut -d'.' -f1)
		if [ "${llvm_ver}" != "${_llvm_major_version:?}" ]; then
			echo "error: llvm/clang-check version mismatch: installed: ${llvm_ver} required: ${_llvm_major_version:?}" 1>&2
			exit 1
		fi

		d=${PWD}
		(cd "${_dir_ref:?}"; tar xf "${d}"/"${_name:?}".tar.xz;)
	else
		rm -rf "${_dir_ref:?}"/*
	fi

	if [ ! -s "${_dir_src:?}"/.git ]; then
		git clone "${_url:?}" "${_dir_src:?}"
	fi
	trap cleanup EXIT

	dmce+="dmce"
	dmce+="	--file ${_dir_tst:?}/.dmceconfig"
	dmce+=" -j $(getconf _NPROCESSORS_ONLN)"
	dmce_set_profile_opts=
	dmce_set_profile_opts+=" --configdir ${_dir_tst:?}/.config/dmce"
	dmce_set_profile_opts+=" --file ${_dir_tst:?}/.dmceconfig"
	dmce_set_profile_opts+=" --keeppaths"
	dmce_set_profile_opts+=" -E $((1024 * 64))"

	pre
}

function list_tests() {
	compgen -A function | grep '^t[0-9]\+' | sort -V
}

function _echo() {
	if [ "$EPOCHREALTIME" != "" ]; then
		echo "${EPOCHREALTIME}: $*"
	else
		echo "$(date '+%Y-%m-%d %H:%M:%S'):$*"
	fi
}

function test_description() {
	local t="${1}"

	if [ "${test_desc[${t}]}" != "" ]; then
		_echo "${t}: ${test_desc[${t}]}"
	else
		_echo "${t}: FIXME: add description"
		sleep 3
	fi
}

function sanity_check_tests() {
	local ret=0

	compgen -A function | grep "^t[0-9]\+$" | sort > "${_dir_tst:?}"/a
	printf "%s\n" "${@}" | sort -u > "${_dir_tst:?}"/b
	comm -1 -3 "${_dir_tst:?}"/{a,b} > "${_dir_tst:?}"/c
	if [ -s "${_dir_tst:?}"/c ]; then
		echo "error: test(s) not found: $(xargs < "${_dir_tst:?}"/c)" 1>&2
		ret=1
	fi
	rm "${_dir_tst:?}"/{a,b,c}
	if [ "${ret}" -ne 0 ]; then
		exit 1
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
			test_description "${t}"
			"${t}"
			i=$((i + 1))
		done
	else
		sanity_check_tests "${@}"
		for t in "${@}"; do
			test_description "${t}"
			"${t}"
			i=$((i + 1))
		done
	fi

	if [ ${_mode:?} -eq 1 ]; then
		(
			cd "${_dir_ref:?}"
			if [ ${#} -eq 0 ]; then
				# create archive
				tar --owner=0 --group=0 -cvJf "${a}"/"${_name:?}".tar.xz -- *.diff
			else
				xz -d "${a}"/"${_name:?}".tar.xz
				# update archive
				tar --owner=0 --group=0 -uvf "${a}"/"${_name:?}".tar -- *.diff
				xz -z "${a}"/"${_name:?}".tar
			fi
		)
	fi

	exit 42
}

# exercise the --include option | profile: coverage
function t0() {
	pre

	${dmce:?} \
		--include main.c \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
	grep -q '^main.c$' "${_dir_dmce:?}"/"${_name:?}"/config/dmce.include
}

# make sure that one untracked file is instrumented | profile: coverage
function t1() {
	pre

	echo 'int main(){int i; i=42;}' > "${FUNCNAME[0]}".c
	${dmce:?} \
		-n 1 \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	grep -q '^int main.*DMCE_PROBE' "${FUNCNAME[0]}".c
	rm "${FUNCNAME[0]}".c
}

# exercise the --head option | profile: coverage
function t2() {
	pre

	${dmce:?} \
		--all \
		--head HEAD~10 \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
	stash_and_checkout
}

# exercise the -a/--all option | profile: coverage
function t3() {
	pre

	${dmce:?} \
		--all \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
	${dmce:?} \
		-a \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
}

# exercise the --version and --help options
function t4() {
	pre

	${dmce:?} --version \
		&> "${t_log:?}"
	${dmce:?} --help \
		>> "${t_log:?}" 2>&1 || true
}

# exercise the -v/--verbose option | profile: coverage
function t5() {
	pre

	${dmce:?} \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
	${dmce:?} -c \
		&> "${t_log:?}"
	${dmce:?} \
		--noepilog \
		--noprolog \
		--profile coverage \
		--verbose \
		&> "${t_log:?}"
	verify
}

# exercise the -n option | profile: coverage
function t6() {
	local i

	for i in $(seq 1 "$(git log --oneline | wc -l)"); do
		pre
		${dmce:?} \
			-n "${i}" \
			--noepilog \
			--noprolog \
			--profile coverage \
			-v \
		&> "${t_log:?}" || true
		verify "${FUNCNAME[0]}.${i}.diff"
	done
}

# conflicting options
function t7() {
	pre

	if ${dmce:?} --include main.c --exclude main.c &> "${t_log:?}"; then
		exit 1
	elif ${dmce:?} -d 52000 &> "${t_log:?}"; then
		exit 1
	elif ${dmce:?} -d -1 &> "${t_log:?}"; then
		exit 1
	elif ${dmce:?} -d a &> "${t_log:?}"; then
		exit 1
	elif dmce -f /dev/null &> "${t_log:?}"; then
		exit 1
	elif ${dmce:?} -m 1 &> "${t_log:?}"; then
		exit 1
	elif ${dmce:?} -m a &> "${t_log:?}"; then
		exit 1
	elif ${dmce:?} -m -1 &> "${t_log:?}"; then
		exit 1
	elif ${dmce:?} -j -1 &> "${t_log:?}"; then
		exit 1
	elif ${dmce:?} -j a &> "${t_log:?}"; then
		exit 1
	elif dmce a &> "${t_log:?}"; then
		exit 1
	elif dmce a b &> "${t_log:?}"; then
		exit 1
	elif dmce -v a &> "${t_log:?}"; then
		exit 1
	elif dmce -v a b &> "${t_log:?}"; then
		exit 1
	fi
}

# untracked and constructs | profile: coverage
function t8() {
	pre

	echo 'int main(){int i; i=42;}' > "${FUNCNAME[0]}".c
	${dmce:?} \
		--constructs i \
		-n 1 \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	if grep -q '^int main.*DMCE_PROBE' "${FUNCNAME[0]}".c; then
		exit 1
	fi
	rm "${FUNCNAME[0]}".c
}

# exercise the coverage probe | profile: coverage
function t9() {
	pre

	${dmce:?} \
		--include simple/main.c,simple/simple.c \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
	${dmce:?} \
		--include simple/main.c,simple/simple.c \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	(
		cd simple
		./build
		./simple
	)
	dmce-summary-bin \
		-v \
		"${_dir_dmce}"/dmcebuffer.bin \
		"${_dir_dmce}"/"${_name:?}"/probe-references.log \
		&> "${t_log:?}"
	grep -q 'Probes executed:5/5' "${t_log:?}"
}

# exercise the heatmap probe | profile: heatmap
function t10() {
	pre

	${dmce:?} \
		--include simple/main.c,simple/simple.c \
		--noepilog \
		--noprolog \
		--profile heatmap \
		-v \
		&> "${t_log:?}"
	verify
	${dmce:?} \
		--include simple/main.c,simple/simple.c \
		--profile heatmap \
		-v \
		&> "${t_log:?}"
	(
		cd simple
		./build
		./simple
	)
	dmce-summary-bin \
		-v \
		"${_dir_dmce}"/dmcebuffer.bin \
		"${_dir_dmce}"/"${_name:?}"/probe-references.log \
		&> "${t_log:?}"
	grep -q 'Probes executed:5/5' "${t_log:?}"
}

function dmce_trace_helper() {
	dmce-trace \
		"$(find "${_dir_dmce}" -maxdepth 1 -type f -name 'dmcebuffer*' | grep -v info$)" \
		"${_dir_dmce}"/"${_name:?}"/probe-references.log \
		"${PWD}" > "${_dir_tst:?}/${FUNCNAME[1]}.log"
}

# exercise the trace-mc probe | profile: trace-mc
function t11() {
	pre

	${dmce:?} \
		--include simple/main.c,simple/simple.c \
		--noepilog \
		--noprolog \
		--profile trace-mc \
		-v \
		&> "${t_log:?}"
	verify
	${dmce:?} \
		--include simple/main.c,simple/simple.c \
		--profile trace-mc \
		-v \
		&> "${t_log:?}"
	(
		cd simple
		./build
		./simple
	) >> "${t_log:?}" 2>&1
	dmce_trace_helper
}

# exercise the trace-mc probe - threads | profile: trace-mc
function t12() {
	pre

	${dmce:?} \
		--include 'threads/.*' \
		--noepilog \
		--noprolog \
		--profile trace-mc \
		-v \
		&> "${t_log:?}"
	verify
	${dmce:?} \
		--include 'threads/.*' \
		--profile trace-mc \
		-v \
		&> "${t_log:?}"
	(
		cd threads
		gcc -o threads -pthread main.c
		./threads
	) >> "${t_log:?}" 2>&1
	dmce_trace_helper
}

# exercise the trace-mc probe - trace-threads | profile: trace-mc
function t13() {
	pre

	${dmce:?} \
		--include 'threads/.*' \
		--noepilog \
		--noprolog \
		--profile trace-mc \
		-v \
		&> "${t_log:?}"
	verify
	${dmce:?} \
		--include 'threads/.*' \
		--profile trace-mc \
		-v \
		&> "${t_log:?}"
	(
		cd threads
		gcc -o trace-threads -pthread trace_threads.c
		./trace-threads || true
	) >> "${t_log:?}" 2>&1
	dmce_trace_helper
}

# exercise the trace-mc probe - trace-threads-hexdump | profile: trace-mc
function t14() {
	pre

	${dmce:?} \
		--include 'threads/.*' \
		--noepilog \
		--noprolog \
		--profile trace-mc \
		-v \
		&> "${t_log:?}"
	verify
	${dmce:?} \
		--include 'threads/.*' \
		--profile trace-mc \
		-v \
		&> "${t_log:?}"
	(
		cd threads
		gcc -o trace-threads-hexdump -pthread trace_threads_hexdump.c
		./trace-threads-hexdump || true
	) >> "${t_log:?}"
	dmce_trace_helper
}

# exercise the --offset option | profile: trace-mc
function t15() {
	local a=${RANDOM}
	local d="${_dir_tst:?}"/"${_name:?}"-"${a}"

	pre

	git worktree add -q "${d}"
	${dmce:?} \
		--profile trace-mc \
		--noepilog \
		--noprolog \
		-v \
		&> "${t_log:?}"
	verify "${FUNCNAME[0]}.0.diff"
	${dmce:?} -c \
		&> "${t_log:?}"
	(
		cd "${d}"
		${dmce:?} \
			--noepilog \
			--noprolog \
			--offset=100000 \
			--profile trace-mc \
			-v \
			&> "${t_log:?}"
		verify "${FUNCNAME[0]}.1.diff"
	)
	grep -q ^100000 "${_dir_dmce}"/"${_name:?}"-"${a}"/probe-references.log
	grep -q -r 'DMCE_PROBE.*\(100000\)' "${d}"
}

# exercise the --offset option in a multi-repo scenario | profile: trace-mc
function t16() {
	local a=${RANDOM}
	local d="${_dir_tst:?}"/"${_name:?}"-"${a}"

	pre

	git worktree add -q "${d}"
	cd "${d}"/simple
	${dmce:?} \
		--include simple/simple.c \
		--profile trace-mc \
		--offset=100000 \
		-v \
		&> "${t_log:?}"
	gcc -fPIC -shared simple.c -o libsimple.so
	${dmce:?} -c \
		&> "${t_log:?}"
	cp -a libsimple.so "${_dir_src:?}"/simple
	cd "${_dir_src:?}"/simple
	${dmce:?} \
		--include simple/main.c \
		--profile trace-mc \
		-v \
		&> "${t_log:?}"
	gcc -c main.c
	gcc main.o -L. -lsimple -o simple
	LD_LIBRARY_PATH=. ./simple
	${dmce:?} -c \
		&> "${t_log:?}"
	dmce-trace \
		"$(find "${_dir_dmce}" -maxdepth 1 -type f -name 'dmcebuffer*' -not -name '*.info')" \
		"${_dir_dmce}"/"${_name:?}"/probe-references-original.log,"${_dir_dmce}"/"${_name:?}"-"${a}"/probe-references-original.log \
		"${_dir_src:?}","${d}" > "${t_log:?}"
	# assure that we have entries from the main repo in the trace
	grep -q "${_dir_src:?}/" "${t_log:?}"
	# assure that we have libsimple entries in the trace
	grep -q "${d}/" "${t_log:?}"
}

# exercise the --include option - one function in one file | profile: coverage
function t17() {
	pre

	${dmce:?} \
		--include threads/main.c:tfunc0 \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
	if [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.include)" -ne 1 ]; then
		exit 1
	fi
	# shellcheck disable=SC2086
	dmce-set-profile ${dmce_set_profile_opts:?} \
		-i threads/main.c:tfunc0 \
		coverage
	${dmce:?} \
		--noepilog \
		--noprolog \
		-v \
		&> "${t_log:?}"
	verify
	if [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.include)" -ne 1 ]; then
		exit 1
	fi
}

# exercise the --include option - multiple functions in one file | profile: coverage
function t18() {
	pre

	${dmce:?} \
		--include threads/main.c:tfunc0,threads/main.c:tfunc1,threads/main.c:tfunc2 \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
	if [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.include)" -ne 3 ]; then
		exit 1
	fi

	# shellcheck disable=SC2086
	dmce-set-profile ${dmce_set_profile_opts:?} \
		-i threads/main.c:tfunc0,threads/main.c:tfunc1,threads/main.c:tfunc2 \
		coverage
	${dmce:?} \
		--noepilog \
		--noprolog \
		-v \
		&> "${t_log:?}"
	verify
	if [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.include)" -ne 3 ]; then
		exit 1
	fi
}

# exercise the --exclude option - exclude one file | profile: coverage
function t19() {
	pre

	${dmce:?} \
		--include 'threads/.*' \
		--exclude threads/main.c \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
}

# exercise the --exclude option - exclude one function in one file | profile: coverage
function t20() {
	pre

	${dmce:?} \
		--include threads/main.c \
		--exclude threads/main.c:tfunc0 \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
	if [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.include)" -ne 1 ]; then
		exit 1
	elif [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.exclude)" -ne 1 ]; then
		exit 1
	fi

	# shellcheck disable=SC2086
	dmce-set-profile ${dmce_set_profile_opts:?} \
		-i threads/main.c \
		-e threads/main.c:tfunc0 \
		coverage
	${dmce:?} \
		--noepilog \
		--noprolog \
		-v \
		&> "${t_log:?}"
	verify
	if [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.include)" -ne 1 ]; then
		exit 1
	elif [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.exclude)" -ne 1 ]; then
		exit 1
	fi
}

# exercise the --exclude option - exclude multiple function in one file | profile: coverage
function t21() {
	pre

	${dmce:?} \
		--include threads/main.c \
		--exclude threads/main.c:tfunc0,threads/main.c:tfunc1,threads/main.c:tfunc2 \
		--noepilog \
		--noprolog \
		--profile coverage \
		-v \
		&> "${t_log:?}"
	verify
	if [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.include)" -ne 1 ]; then
		exit 1
	elif [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.exclude)" -ne 3 ]; then
		exit 1
	fi

	# shellcheck disable=SC2086
	dmce-set-profile ${dmce_set_profile_opts:?} \
		-i threads/main.c \
		-e threads/main.c:tfunc0,threads/main.c:tfunc1,threads/main.c:tfunc2 \
		coverage
	${dmce:?} \
		--noepilog \
		--noprolog \
		-v \
		&> "${t_log:?}"
	verify
	if [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.include)" -ne 1 ]; then
		exit 1
	elif [ "$(wc -l < "${_dir_dmce:?}"/"${_name:?}"/config/dmce.exclude)" -ne 3 ]; then
		exit 1
	fi
}

# exercise through all probes | profile: all
function t22() {
	local i
	local p

	i=0
	for p in $(dmce-set-profile -l); do
		pre
		${dmce:?} \
			--include main.c \
			--noepilog \
			--noprolog \
			--profile "${p}" \
			-v \
		&> "${t_log:?}" || true
		# racetrace adds random delay => skip verification
		if [ "$p" != "racetrack" ]; then
			verify "${FUNCNAME[0]}.${i}.diff"
		fi
		i=$((i + 1))
	done
}

# exercise the racetrack probe - trace-threads | profile: trace-mc
function t23() {
	pre

	${dmce:?} \
		--include 'threads/.*' \
		--profile racetrack \
		-v \
		&> "${t_log:?}"
	(
		cd threads
		gcc -o trace-threads -pthread trace_threads.c
		./trace-threads || true
	) >> "${t_log:?}" 2>&1
}

main "${@}"
