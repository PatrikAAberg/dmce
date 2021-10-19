#!/usr/bin/env bash
numVars=$1
set -e

# Hard coded or follow distro
#gcc_version=$(gcc --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 | sed -e 's|[0-9]\+$|0|g')
gcc_version="9.3.0"

PROG_NAME=$(basename $0 .sh)

function _echo() {
	local a

	if [ "x$numVars" != "x" ]; then
		a="${PROG_NAME}-${numVars}"
	else
		a="${PROG_NAME}"
	fi

	echo $(date '+%Y-%m-%d %H:%M:%S'):${a}:$@
}
_echo "running gcc.dg-torture"

# DMCE work directory
dmce_work_path="/tmp/${USER}/dmce"

# test work directory
my_work_path="${dmce_work_path}/test/${PROG_NAME}"
my_test_path=$(dirname $(echo ${PWD}/$0))
mkdir -v -p ${my_work_path}
[ -d ${my_work_path}/gcc-${gcc_version} ] && rm -rf ${my_work_path}/gcc-${gcc_version}

# temporary hide errors
set +e
# DMCE exec directory
dmce_exec_path="$(git rev-parse --show-toplevel 2> /dev/null)"
if [ $? -ne 0 ]; then
	set -e
	if ! [ -e dmce/.git ]; then
		_echo "fetch DMCE"
		git -C ${my_work_path} clone --depth 1 https://github.com/PatrikAAberg/dmce.git
	fi
	dmce_exec_path=${PWD}/dmce
fi
set -e

cd ${my_work_path}

if [ -e "gcc-${gcc_version}.tar.xz" ]; then
	archive="xz"
elif [ -e "gcc-${gcc_version}.tar.gz" ]; then
	archive="gz"
else
	_echo "fetch GCC"
	# try xz first
	if ! wget -q https://ftp.gnu.org/gnu/gcc/gcc-${gcc_version}/gcc-${gcc_version}.tar.xz; then
		# then gz
		if ! wget -q https://ftp.gnu.org/gnu/gcc/gcc-${gcc_version}/gcc-${gcc_version}.tar.gz; then
			echo "error: can not find gcc version: ${gcc_version} at 'ftp.gnu.org'"
			exit 1
		fi
		archive="gz"
	else
		archive="xz"
	fi
fi

_echo "unpack GCC"
tar -C ${my_work_path} -xf gcc-${gcc_version}.tar.${archive} gcc-${gcc_version}/gcc/testsuite/${PROG_NAME}

_echo "create git"
cd gcc-${gcc_version}/gcc/testsuite/${PROG_NAME}

git init -q
git config gc.autoDetach false
git commit -q -m "empty" --allow-empty
git add .
git commit -q -m "initial commit"

# gcc version or standard diffs, we are not that picky for this usage
set +e
git rm -q compile/20011119-1.c
git rm -q compile/20000120-2.c
git rm -q compile/20011119-2.c
git rm -q compile/20030305-1.c
git rm -q compile/20050215-1.c
git rm -q compile/20050215-2.c
git rm -q compile/20050215-3.c
git rm -q compile/20111209-1.c
git rm -q compile/20160205-1.c
git rm -q compile/920520-1.c
git rm -q compile/920521-1.c
git rm -q compile/dll.c
git rm -q compile/limits-*.c
git rm -q compile/mipscop-1.c
git rm -q compile/mipscop-2.c
git rm -q compile/mipscop-3.c
git rm -q compile/mipscop-4.c
git rm -q compile/pr37669.c
git rm -q compile/pr46534.c
git rm -q compile/pr67143.c
git rm -q compile/pr70199.c
git rm -q compile/pr70633.c
git rm -q execute/20000227-1.c
git rm -q execute/20010206-1.c
git rm -q execute/fprintf-chk-1.c
git rm -q execute/pr19449.c
git rm -q execute/pr67714.c
git rm -q execute/pr68532.c
git rm -q execute/pr71494.c
git rm -q execute/printf-chk-1.c
git rm -q execute/vfprintf-chk-1.c
git rm -q execute/vprintf-chk-1.c
git rm -q unsorted/dump-noaddr.c
git rm -q compile/20001226-1.c
set -e
git commit -q -m "broken"

_echo "remove files that does not compile"
> ${my_work_path}/compile-errors
while read -r f; do
	{
		if ! gcc -w -c -std=c++11 ${f} &> /dev/null; then
			echo ${f} >> ${my_work_path}/compile-errors;
		fi
	} &
done < <(git ls-files)
wait
if [ -s ${my_work_path}/compile-errors ]; then
	while read -r f; do
		git rm -q $f
	done <${my_work_path}/compile-errors
	git commit -q -m "does not compile"
fi

# add DMCE config and update paths
cp -v ${dmce_exec_path}/test/${PROG_NAME}/dmceconfig .dmceconfig
sed -i "s|DMCE_EXEC_PATH:.*|DMCE_EXEC_PATH:${dmce_exec_path}|" .dmceconfig
sed -i "s|DMCE_CONFIG_PATH:.*|DMCE_CONFIG_PATH:${my_test_path}|" .dmceconfig
sed -i "s|DMCE_CMD_LOOKUP_HOOK:.*|DMCE_CMD_LOOKUP_HOOK:${my_test_path}/cmdlookuphook.sh|" .dmceconfig
if [[ "$numVars" -eq "0" ]]; then
    echo "No data trace probes enabled"
    sed -i "s|DMCE_PROBE_SOURCE:.*|DMCE_PROBE_SOURCE:${my_test_path}/dmce-probe-test.c|" .dmceconfig
    sed -i "s|DMCE_PROBE_PROLOG:.*|DMCE_PROBE_PROLOG:${my_test_path}/dmce-prolog-test.c|" .dmceconfig
else
    echo "5 variables probes enabled"
    sed -i "s|DMCE_PROBE_SOURCE:.*|DMCE_PROBE_SOURCE:${my_test_path}/dmce-probe-test-D5.c|" .dmceconfig
    sed -i "s|DMCE_PROBE_PROLOG:.*|DMCE_PROBE_PROLOG:${my_test_path}/dmce-prolog-test-D5.c|" .dmceconfig
    echo "DMCE_NUM_DATA_VARS:5" >> .dmceconfig
    echo "DMCE_TRACE_VAR_TYPE:unsigned long" >> .dmceconfig
fi

git add .dmceconfig
git commit -q -m "DMCE config"
git --no-pager log --oneline --shortstat --no-color

_echo "launch DMCE"
${dmce_exec_path}/dmce-launcher -n $(git rev-list --all --count) --debug

_echo "compile"
> ${my_work_path}/compile-errors
find -name '*.err' -exec rm {} \;

if [ ! -s "${dmce_work_path}/${PROG_NAME}/workarea/probe-list" ]; then
	echo "error: empty probe-list"
	exit 1
fi

while read -r f; do
	{
		if ! gcc -w -c -std=c++11 ${f} 2>> "${f}".err; then
			echo ${f} >> ${my_work_path}/compile-errors;
		fi
	} &
done < ${dmce_work_path}/${PROG_NAME}/workarea/probe-list
wait
find -name '*.err' -type f ! -size 0 -exec cat {} \;
errors=$(wc -l < ${my_work_path}/compile-errors)
_echo "exit: ${errors}"
exit ${errors}
