#!/usr/bin/env bash

set -e

echo "Running g++.dg-torture"

gcc_version=$(gcc --version| grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+'|head -1)
PROG_NAME=$(basename $0 .sh)
function _echo() {
	echo $(date '+%Y-%m-%d %H:%M:%S'):${PROG_NAME}:$@
}

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
		set -x
		git -C ${my_work_path} clone --depth 1 https://github.com/PatrikAAberg/dmce.git
		{ set +x; } 2>/dev/null
	fi
	dmce_exec_path=${PWD}/dmce
fi
set -e

pushd ${my_work_path} &> /dev/null

if [ ! -e "gcc-${gcc_version}.tar.xz" ]; then
	_echo "fetch GCC"
	set -x
	if ! wget -q https://ftp.gnu.org/gnu/gcc/gcc-${gcc_version}/gcc-${gcc_version}.tar.xz; then
		echo "error: can not find gcc version: ${gcc_version} at 'ftp.gnu.org'"
		exit 1
	fi
	{ set +x; } 2>/dev/null
fi

_echo "unpack GCC"
set -x
tar -C ${my_work_path} -xf gcc-${gcc_version}.tar.xz gcc-${gcc_version}/gcc/testsuite/g++.dg
mkdir gcc-${gcc_version}/gcc/testsuite/${PROG_NAME}
pushd gcc-${gcc_version}/gcc/testsuite/g++.dg
grep -rLE "dg-error|deprecated|concepts|sorry" | xargs -I{} cp {} ../${PROG_NAME}/
popd
rm -rf gcc-${gcc_version}/gcc/testsuite/g++.dg
{ set +x; } 2>/dev/null

_echo "create git"
set -x
cd gcc-${gcc_version}/gcc/testsuite/${PROG_NAME}

set +x
shopt -s globstar
for f in ../**/*.C; do mv "$f" "${f%.C}.cpp"; done
for f in ../**/*.H; do mv "$f" "${f%.H}.h"; done
set -x

git init
git commit -m "empty" --allow-empty
git add .
git commit -m "initial commit"

# Put crossed out ones here
#git rm pr49644.cpp             # using namespace std::complex_literals
#git rm pr91355.cpp             # dynamic exception specifications are deprecated
#git rm pr82154.cpp             # dynamic exception specifications are deprecated
#git rm pr70621.cpp             # Does not compile
#git rm pr68220.cpp             # -fno-new-ttp-matching
#git rm accessor-fixits-7.cpp   # Does not compile
#git rm darwin-cfstring-3.cpp   # Does not compile
#git rm pr64280.cpp             # Does not compile
#git rm pr56768.cpp             # bool operator!= (Iter &, Iter &) { return(DMCE_PROBE(1636), true); }
#git rm pr58380.cpp             # (DMCE_PROBE(TBD),  ~vector());

# all except marked ones are dg-error
#git rm non-dependent2.cpp
#git rm template29.cpp
#git rm crash44.cpp
#git rm template28.cpp
#git rm constant4.cpp
#git rm crash58.cpp
#git rm missing-template1.cpp
#git rm crash23.cpp
#git rm colon-autocorrect-1.cpp
#git rm typename7.cpp
#git rm crash40.cpp
#git rm pr20118.cpp
#git rm friend-main.cpp
#git rm error20.cpp
#git rm crash13.cpp
#git rm pr18770.cpp
#git rm error31.cpp
#git rm else.cpp
#git rm dtor15.cpp
#git rm error11.cpp
#git rm pr70635.cpp
#git rm ivdep.cpp
#git rm fn-template2.cpp
#git rm lookup3.cpp
#git rm class1.cpp
#git rm varmod1.cpp # dg-message
#git rm error61.cpp
#git rm pr83634.cpp
#git rm crash30.cpp
#git rm casting-operator2.cpp
#git rm error14.cpp
#git rm pr26997.cpp
#git rm semicolon3.cpp
#git rm namespace-definition.cpp
#git rm limits-initializer1.cpp
#git commit -m "broken"

# add DMCE config and update paths

cp -v ${dmce_exec_path}/test/${PROG_NAME}/dmceconfig .dmceconfig
sed -i "s|DMCE_EXEC_PATH:.*|DMCE_EXEC_PATH:${dmce_exec_path}|" .dmceconfig
sed -i "s|DMCE_CONFIG_PATH:.*|DMCE_CONFIG_PATH:${my_test_path}|" .dmceconfig
sed -i "s|DMCE_CMD_LOOKUP_HOOK:.*|DMCE_CMD_LOOKUP_HOOK:${my_test_path}/cmdlookuphook.sh|" .dmceconfig
sed -i "s|DMCE_PROBE_SOURCE:.*|DMCE_PROBE_SOURCE:${my_test_path}/dmce-probe-monolith.c|" .dmceconfig
git add .dmceconfig
git commit -m "DMCE config"
{ set +x; } 2>/dev/null

_echo "launch DMCE"
set -x
${dmce_exec_path}/dmce-launcher -n $(git rev-list --all --count)
{ set +x; } 2>/dev/null

	_echo "compile"
	> ${my_work_path}/compile-errors
	find -name '*.err' -exec rm {} \;
	for f in $(cat ${dmce_work_path}/${PROG_NAME}/workarea/probe-list); do
		{
			if ! gcc -w -c -fpermissive -std=c++17 ${f} 2>> "${f}".err; then
				echo ${f} >> ${my_work_path}/compile-errors;
			fi
		} &
done

wait

set -x
find -name '*.err' -type f ! -size 0 -exec cat {} \;
{ set +x; } 2>/dev/null

_echo "results"
set -x
find ${dmce_work_path} -maxdepth 1  -type f -name "dmce-launcher-${PROG_NAME}-*" -printf '%T@ %p\n' | sort -nr | head -1 | awk '{print $2}' | xargs tail -v
{ set +x; } 2>/dev/null

errors=$(cat ${my_work_path}/compile-errors | wc -l)
_echo "exit: ${errors}"
exit ${errors}
