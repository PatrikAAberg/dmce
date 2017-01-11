#!/bin/bash

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

# If no arguments, operate on all files in current directory
# If one argument, operate on that argument as one file
# TODO: take more than one argument

if [ "$1" == "" ]; then

# Save all files under inc in one varaible
files=$(echo *)

# Count number of files within that variable
number_of_files=$(tr -dc ' ' <<<"$files" | awk '{ print length; }')

# How many processing units available?
CORES=$(nproc)

# Divide number of files on each core
interval=$(($number_of_files/$CORES))

# variables for 'cut'
a=1
b=1

# List of 'sed' PIDs
PIDS=

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
  sed -i 's/#\s*include\s\(\"\|<\).*\/\(.*\)\(\"\|>\).*/#include \"\2\"/g' $sub_files &

  # Save the PID
  PIDS="$PIDS $!"
done

echo "waiting for $(ps -o pid= -p $PIDS | wc  -l) spawned 'sed' jobs to finish, this may take a while."
wait

else
  sed -i 's/#\s*include\s\(\"\|<\).*\/\(.*\)\(\"\|>\).*/#include \"\2\"/g' $1
fi
