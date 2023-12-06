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

n="dmce-examples"
f="${n}.tar.xz"
if [ ! -s "${f:?}" ]; then
	echo "error: run from the 'test/${n:?}/' directory" 1>&2
	exit 1
fi
function cleanup {
	if [ -d before ]; then
		rm -rf before
	fi
	if [ -d after ]; then
		rm -rf after
	fi
}
trap cleanup EXIT
cleanup
mkdir before after
git show origin/master:test/"${n}"/"${f}" >before/"${f}"
cp -a "${f}" after/
(cd before; tar -xf "${f}")
(cd after; tar -xf "${f}")
diff -x "${f}" -q -r before after
