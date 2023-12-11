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

_dmce_list_files() {
	if ! git rev-parse --git-dir &> /dev/null; then
		return
	fi
	git ls-files | \
		grep -E '\.c$|\.cpp$|\.cc$|\.h$|\.hh$|\.hpp$|\.inc$'
}

_dmce_list_profiles() {
	if ! command -v dmce-set-profile > /dev/null; then
		return
	fi
	dmce-set-profile -l
}

_dmce() {
	declare -a opts
	local cur
	local prev

	opts+=('-a')
	opts+=('--all')
	opts+=('-c')
	opts+=('-C')
	opts+=('--cache')
	opts+=('--calltrace')
	opts+=('--constructs')
	opts+=('-d')
	opts+=('--debug')
	opts+=('--exclude')
	opts+=('-f')
	opts+=('--file')
	opts+=('-h')
	opts+=('--head')
	opts+=('--head=')
	opts+=('--help')
	opts+=('--include')
	opts+=('-j')
	opts+=('-m')
	opts+=('-n')
	opts+=('--noepilog')
	opts+=('--noprolog')
	opts+=('--offset')
	opts+=('--offset=')
	opts+=('-p')
	opts+=('--profile')
	opts+=('-r')
	opts+=('-s')
	opts+=('--structs')
	opts+=('--update-config')
	opts+=('-v')
	opts+=('--varexclude')
	opts+=('--varinclude')
	opts+=('--verbose')
	opts+=('--version')

	if [ "$(type -t _init_completion)" != "function" ]; then
		return
	elif ! _init_completion -n =; then
		return
	fi

	case $cur in
		-*)
			mapfile -t COMPREPLY < <(compgen -W "${opts[*]}" -- "$cur")
			return
			;;
	esac

	case $prev in
		--file)
			_filedir
			return
			;;
		--exclude|--include)
			if [ "${cur: -1}" = "," ]; then
				f=$(_dmce_list_files | sed -e "s|^|${cur}|g" | xargs)
			elif [[ "${cur}" == *,* ]]; then
				f=$(_dmce_list_files | sed -e "s|^|${cur%,*},|g" | xargs)
			else
				f=$(_dmce_list_files)
			fi
			mapfile -t COMPREPLY < <(compgen -W "${f}" -- "$cur")
			return
			;;
		-j)
			mapfile -t COMPREPLY < <(compgen -W "$(seq 1 "$(getconf _NPROCESSORS_ONLN)")" -- "$cur")
			return
			;;
		-m)
			mapfile -t COMPREPLY < <(compgen -W "$(seq 1 100)" -- "$cur")
			return
			;;
		-p|--profile)
			mapfile -t COMPREPLY < <(compgen -W "$(_dmce_list_profiles)" -- "$cur")
			return
			;;
	esac
}

_dmce_set_profile() {
	declare -a opts
	local cur
	local prev

	opts+=('-c')
	opts+=('-C')
	opts+=('--cache')
	opts+=('--constructs')
	opts+=('-d')
	opts+=('-e')
	opts+=('-E')
	opts+=('--exclude')
	opts+=('--excludecapitals')
	opts+=('-f')
	opts+=('--file')
	opts+=('--fixnullptr')
	opts+=('-h')
	opts+=('--help')
	opts+=('-i')
	opts+=('-I')
	opts+=('--include')
	opts+=('--keeppaths')
	opts+=('-l')
	opts+=('--listprofiles')
	opts+=('-m')
	opts+=('-M')
	opts+=('--memlimit')
	opts+=('-n')
	opts+=('--noderefs')
	opts+=('--nosignals')
	opts+=('--notemplates')
	opts+=('-p')
	opts+=('-r')
	opts+=('-s')
	opts+=('-S')
	opts+=('--sysincludes')
	opts+=('-t')
	opts+=('-T')
	opts+=('--tentries')
	opts+=('--toplevel')
	opts+=('-v')
	opts+=('--varexclude')
	opts+=('--varinclude')
	opts+=('--verbose')
	opts+=('-y')
	opts+=('-Y')

	if ! _init_completion -n =; then
		return
	fi

	case $cur in
		-*)
			mapfile -t COMPREPLY < <(compgen -W "${opts[*]}" -- "$cur")
			return
			;;
	esac

	case $prev in
		-f|--file)
			_filedir
			return
			;;
		--exclude|--include)
			if [ "${cur: -1}" = "," ]; then
				f=$(_dmce_list_files | sed -e "s|^|${cur}|g" | xargs)
			elif [[ "${cur}" == *,* ]]; then
				f=$(_dmce_list_files | sed -e "s|^|${cur%,*},|g" | xargs)
			else
				f=$(_dmce_list_files)
			fi
			mapfile -t COMPREPLY < <(compgen -W "${f}" -- "$cur")
			return
			;;
		-m|--memlimit)
			mapfile -t COMPREPLY < <(compgen -W "$(seq 1 100)" -- "$cur")
			return
			;;
	esac

	mapfile -t COMPREPLY < <(compgen -W "$(_dmce_list_profiles)" -- "$cur")
}

complete -F _dmce dmce
complete -F _dmce_set_profile dmce-set-profile
