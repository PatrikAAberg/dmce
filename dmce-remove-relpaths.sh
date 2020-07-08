#!/usr/bin/env bash

# Copyright (c) 2016 Ericsson AB
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# $1 = a file or a directory

NAME=$(basename $0)

function _sed() {
	sed -i 's/#\s*include\s\(\"\|<\).*\/\(.*\)\(\"\|>\).*/#include \"\2\"/g' $@
}

if [ -f $1 ]; then
	_sed $1
elif [ -d $1 ]; then
	# Enter directory
	cd $1

	# Exit if directory is empty
	[ ! -n "$(ls -A)" ] && exit 1

	# Save all files in one variable
	files=$(find -type f -printf "%f ")

	# Count number of spaces = number of files
	number_of_files=$(tr -dc ' ' <<<"$files" | awk '{ print length; }')

	# How many processing units are available on this machine?
	CORES=$(nproc)

	# Run sed and exit if we just have a few files
	if [ $number_of_files -lt $CORES ]; then
		_sed $files
		exit
	fi

	# Divide number of files on each core
	interval=$(($number_of_files/$CORES))

	# variables for 'cut'
	a=1
	b=1

	# Launch $CORES jobs
	for i in $(seq $CORES); do
		a=$b
		let "b = b + $interval"

		# Divide $files into smaller chunks, let last core handle a few more files
		if [ $i == $CORES ]; then
		  sub_files=$(cut -d' ' -f$a- <(echo $files))
		else
		  sub_files=$(cut -d' ' -f$a-$b <(echo $files))
		fi

		# Launch the command
		_sed $sub_files &
	done

	echo "${NAME}: waiting for spawned 'sed' jobs to finish, this may take a while."
	wait
fi
