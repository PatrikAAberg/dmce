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

git rm Wdouble-promotion.cpp                # Complex numbers macro expansion
git rm Wclass-memaccess.cpp                 # Macro expansion of macro with only one capital letter
git rm altivec-cell-3.cpp                   # altivec.h: No such file or directory
git rm atomics-1.cpp                        # simulate-thread.h: No such file or directory
git rm altivec-3.cpp                        # altivec.h: No such file or directory
git rm asm3.cpp                             # __asm__
git rm aligned-new8.cpp                     # DMCE_PROBE(TBD), crash?
git rm auto-fn15.cpp                        # auto declarations
git rm constexpr-array-ptr9.cpp             # Assert macro
git rm decomp2.cpp                          # Complex numbers macro expansion
git rm constexpr-arith-overflow.cpp         # Assert macro
git rm constexpr-56302.cpp                  # __asm
git rm darwin-cfstring-3.cpp                # __asm
git rm elision2.cpp                         # use of deleted function
git rm altivec-1.cpp                        # altivec.h: No such file or directory
git rm bitfields.cpp                        # simulate-thread.h: No such file or directory
git rm darwin-minversion-1.cpp              # simulate-thread.h: No such file or directory
git rm constexpr-attribute.cpp              # __attribute__
git rm auto-fn32.cpp                        # auto declarations
git rm fn-template9.cpp                     # std=c++2a
git rm elision.cpp                          # TO CHECK: return does smth with private
git rm move-return1.cpp                     # deleted function
git rm defaulted21.cpp                      # deleted function
git rm atomics-2.cpp                        # simulate-thread.h: No such file or directory
git rm lambda-uneval9.cpp                   # std=c++2a
git rm dllimport2.cpp                       # __attribute__
git rm noexcept-1.cpp                       # TO CHECK: constexpr
git rm noexcept-6.cpp                       # TO CHECK: constexpr
git rm asan_mem_test.cc                     # TO CHECK: constexpr
git rm calloc.cpp                           # TO CHECK: indirect function call within transaction safe function
git rm asan_oob_test.cc                     # #error, lack gtest
git rm asan_str_test.cc                     # #error, lack gtest
git rm asan_globals_test.cc                 # #error, lack gtest
git rm asan_test.cc                         # #error, lack gtest
git rm sanitizer_test_utils.h               # include file "vector" not found
git rm range-test-1.cpp                     # range-test-1.C: No such file or directory
git rm range-test-2.cpp                     # range-test-2.C: No such file or directory
git rm attribute_plugin.c                   # gcc-plugin.h: No such file or directory
git rm def_plugin.c                         # gcc-plugin.h: No such file or directory
git rm gen-attrs-21.cpp                     # TO CHECK: string handling
git rm gen-attrs-48.cpp                     # TO CHECK: string handling
git rm mangle60.cpp                         # TO CHECK: numeric literal operators
git rm bitfields-2.cpp                      # simulate-thread.h: No such file or directory
git rm invisiref2.cpp                       # use of deleted function
git rm arm-fp16-ops.h                       # unknown type name '__fp16'
git rm invisiref2a.cpp                      # use of deleted function
git rm default-arg1.cpp                     # DMCE_PROBE(TBD), crash?
git rm gen-attrs-49.cpp                     # TO CHECK: string handling
git rm initlist-deduce.cpp                  # TO CHECK: tbd
git rm pr42337.cpp                          # TO CHECK: tbd
git rm pch.cpp                              # pch.H: no such file or directory
git rm inline12.cpp                         # DMCE_PROBE(TBD), crash?

git rm noexcept-3.cpp
git rm pr47530-2.cpp
git rm altivec-cell-2.cpp
git rm decl_plugin.c
git rm nontype-class1.cpp
git rm lambda-uneval4.cpp
git rm lambda-uneval3.cpp
git rm lambda-uneval7.cpp
git rm constexpr-sizeof1.cpp
git rm pr45940.cpp
git rm complex3.cpp
git rm comment_plugin.c
git rm altivec-cell-4.cpp
git rm multiple-overflow-warn-2.cpp
git rm lambda-generic-variadic17.cpp
git rm fp16-overload-1.cpp
git rm pr45940-2.cpp
git rm nontype-class4.cpp
git rm dumb_plugin.c
git rm nontype-class3.cpp
git rm pr49644.cpp
git rm paren1.cpp
git rm constexpr-array19.cpp
git rm header_plugin.c
git rm gen-attrs-50.cpp
git rm fn-template3.cpp
git rm ia64-1.cpp
git rm opaque-2.cpp
git rm opaque-1.cpp
git rm pr56419.cpp
git rm pr55073.cpp
git rm i386-10.cpp
git rm lambda-uneval9.cc
git rm pr54300.cpp
git rm arm-neon-1.cpp
git rm nvptx-ptrmem1.cpp
git rm o32-fp.cpp
git rm check-vect.h
git rm gcov-3.h
git rm local-1.cpp
git rm empty.cpp
git rm pr20366.cpp
git rm destroying-delete1.cpp
git rm ppc64-sighandle-cr.cpp
git rm asm1.c
git rm pr56768.cpp
git rm pr47530.cpp
git rm pr51516.cpp
git rm pr84548.cpp
git rm pr64688-2.cpp
git rm pr64076_0.cpp
git rm pr84943-2.cpp
git rm pr64688.cpp
git rm pr58380.cpp
git rm pr63621.cpp
git rm asm5.c
git rm pr68220.cpp
git rm pr85657.cpp
git rm pr85503.cpp
git rm pragma_plugin.c
git rm pr78229.cpp
git rm pr82410.cpp
git rm simd-clone-6.cc
git rm simd-clone-4.cc
git rm simd-clone-2.cc
git rm simd-clone-1.cc
git rm static-1.cpp
git rm pr77844.cpp
git rm system-2.cpp
git rm template-2.cpp
git rm struct-layout-1_generate.c
git rm system-binary-constants-1.cpp
git rm system-1.cpp
git rm structret1.cpp
git rm pr60150_0.cpp
git rm pr90326.cpp
git rm utf-type-char8_t.cpp
git rm var-templ1.cpp
git rm using57.cpp
git rm unexpected1_x.cpp
git rm va-arg-pack-len-1.cpp
git rm struct-layout-1_x1.h
git rm copyprop.cpp
git rm varmod1.cpp
git rm typeof6.cpp
git rm variadic98.cpp
git rm udlit-resolve-char8_t.cpp
git rm variadic87.cpp
git rm typeof1.cpp
git rm visibility-9.cpp
git rm gcov-3.cpp
git rm simd-2.cpp

git commit -m "broken"

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
			if ! gcc -w -c -fpermissive -fgnu-tm -std=c++17 ${f} 2>> "${f}".err; then
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
