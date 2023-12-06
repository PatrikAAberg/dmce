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

declare -a t_list
declare -a ok
declare -a nok

t_list+=('gcc_torture')
t_list+=('gplusplus_torture')
t_list+=('unittest')

d="${PWD}"
trap true SIGINT
for t in ${t_list[*]}; do
	if command -v figlet > /dev/null; then
		figlet -t "$t" 2> /dev/null
	else
		echo "$t"
	fi
	t_exe="${t}.sh"
	if [ ! -s "${d}/${t}/${t_exe:?}" ]; then
		echo "error: '${t_exe:?}' not found for test '$t'"
		exit 1
	fi
	cd "${d}/${t}" || exit 1
	if ! "./${t_exe:?}"; then
		nok+=("$t")
	else
		ok+=("$t")
	fi
done

echo
printf "===============================================\n"
{
	echo "OK@${#ok[*]}@${ok[*]}"
	echo "NOK@${#nok[*]}@${nok[*]}"
} | column -t -s'@'
printf "===============================================\n"
