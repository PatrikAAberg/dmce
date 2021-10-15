#!/usr/bin/env bash
numVars=$1
set -e

echo "Running g++.dg-torture"

# Hard coded or follow distro
#gcc_version=$(gcc --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1 | sed -e 's|[0-9]\+$|0|g')
gcc_version="9.3.0"

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
tar -C ${my_work_path} -xf gcc-${gcc_version}.tar.${archive} gcc-${gcc_version}/gcc/testsuite/g++.dg
mkdir gcc-${gcc_version}/gcc/testsuite/${PROG_NAME}

cd gcc-${gcc_version}/gcc/testsuite/g++.dg
cp -a --parents $(grep -rLE "dg-error|deprecated|concepts|sorry" *) ../${PROG_NAME}/
cd -
rm -rf gcc-${gcc_version}/gcc/testsuite/g++.dg

_echo "create git"
cd gcc-${gcc_version}/gcc/testsuite/${PROG_NAME}

shopt -s globstar
for f in ../**/*.C; do mv "$f" "${f%.C}.cpp"; done
for f in ../**/*.H; do cp "$f" "${f%.H}.h"; done
for f in ../**/*.Hs; do mv "$f" "${f%.Hs}.H"; done

git init
git config gc.autoDetach false
git commit -m "empty" --allow-empty
git add .
git commit -m "initial commit"

# Put crossed out ones here
rm_file_list+=" Wclass-memaccess.cpp"                 # Macro expansion of macro with only one capital letter
rm_file_list+=" altivec-cell-3.cpp"                   # ppc
rm_file_list+=" atomics-1.cpp"                        # simulate-thread.h: No such file or directory
rm_file_list+=" altivec-3.cpp"                        # altivec.h: No such file or directory
rm_file_list+=" asm3.cpp"                             # __asm__
rm_file_list+=" aligned-new8.cpp"                     # DMCE_PROBE(TBD), crash?
rm_file_list+=" auto-fn15.cpp"                        # auto declarations
rm_file_list+=" constexpr-56302.cpp"                  # __asm
rm_file_list+=" darwin-cfstring-3.cpp"                # __asm
rm_file_list+=" elision2.cpp"                         # use of deleted function
rm_file_list+=" altivec-1.cpp"                        # ppc
rm_file_list+=" bitfields.cpp"                        # simulate-thread.h: No such file or directory
rm_file_list+=" darwin-minversion-1.cpp"              # simulate-thread.h: No such file or directory
rm_file_list+=" constexpr-attribute.cpp"              # DMCE_PROBE(TBD), crash?
rm_file_list+=" auto-fn32.cpp"                        # auto declarations
rm_file_list+=" fn-template9.cpp"                     # std=c++2a
rm_file_list+=" elision.cpp"                          # a bug (not following standard) in gcc around the comma separator?
rm_file_list+=" move-return1.cpp"                     # deleted function
rm_file_list+=" defaulted21.cpp"                      # deleted function
rm_file_list+=" atomics-2.cpp"                        # simulate-thread.h: No such file or directory
rm_file_list+=" lambda-uneval9.cpp"                   # std=c++2a
rm_file_list+=" dllimport2.cpp"                       # reference by dll linkage
rm_file_list+=" noexcept-1.cpp"                       # calling constexpr method via struct is marked in AST as normal function call
rm_file_list+=" noexcept-6.cpp"                       # calling constexpr method via struct is marked in AST as normal function call
rm_file_list+=" asan_mem_test.cc"                     # calling constexpr method via struct is marked in AST as normal function call
rm_file_list+=" calloc.cpp"                           # Does not build before probing
rm_file_list+=" asan_oob_test.cc"                     # #error, lack gtest
rm_file_list+=" asan_str_test.cc"                     # #error, lack gtest
rm_file_list+=" asan_globals_test.cc"                 # #error, lack gtest
rm_file_list+=" asan_test.cc"                         # #error, lack gtest
rm_file_list+=" sanitizer_test_utils.h"               # include file "vector" not found
rm_file_list+=" range-test-1.cpp"                     # range-test-1.C: No such file or directory
rm_file_list+=" range-test-2.cpp"                     # range-test-2.C: No such file or directory
rm_file_list+=" attribute_plugin.c"                   # gcc-plugin.h: No such file or directory
rm_file_list+=" def_plugin.c"                         # gcc-plugin.h: No such file or directory
rm_file_list+=" gen-attrs-21.cpp"                     # static assert, something goes very wrong here
rm_file_list+=" gen-attrs-48.cpp"                     # static assert, something goes very wrong here
rm_file_list+=" bitfields-2.cpp"                      # simulate-thread.h: No such file or directory
rm_file_list+=" invisiref2.cpp"                       # use of deleted function
rm_file_list+=" arm-fp16-ops.h"                       # unknown type name '__fp16'
rm_file_list+=" invisiref2a.cpp"                      # use of deleted function
rm_file_list+=" default-arg1.cpp"                     # DMCE_PROBE(TBD), crash?
rm_file_list+=" pr42337.cpp"                          # Does not build before probing
rm_file_list+=" inline12.cpp"                         # DMCE_PROBE(TBD), crash?
rm_file_list+=" noexcept-3.cpp"                       # calling constexpr method via struct is marked in AST as normal function call
rm_file_list+=" altivec-cell-2.cpp"                   # ppc
rm_file_list+=" decl_plugin.c"                        # gcc-plugin.h: no such file or directory
rm_file_list+=" nontype-class1.cpp"                   # std=c++2a
rm_file_list+=" lambda-uneval4.cpp"                   # std=c++2a
rm_file_list+=" lambda-uneval3.cpp"                   # std=c++2a
rm_file_list+=" lambda-uneval7.cpp"                   # std=c++2a
rm_file_list+=" comment_plugin.c"                     # gcc-plugin.h: no such file or directory
rm_file_list+=" altivec-cell-4.cpp"                   # ppc
rm_file_list+=" multiple-overflow-warn-2.cpp"         # DMCE_PROBE(TBD), crash?
rm_file_list+=" fp16-overload-1.cpp"                  # __fp16
rm_file_list+=" nontype-class4.cpp"                   # std=c++2a
rm_file_list+=" dumb_plugin.c"                        # gcc-plugin.h: no such file or directory
rm_file_list+=" nontype-class3.cpp"                   # std=c++2a
rm_file_list+=" paren1.cpp"                           # use of deleted function
rm_file_list+=" constexpr-array19.cpp"                # static_assert()
rm_file_list+=" header_plugin.c"                      # gcc-plugin.h: no such file or directory
rm_file_list+=" fn-template3.cpp"                     # std=c++2a
rm_file_list+=" ia64-1.cpp"                           # __asm
rm_file_list+=" opaque-2.cpp"                         # __ev64_opaque__
rm_file_list+=" opaque-1.cpp"                         # __ev64_opaque__
rm_file_list+=" pr55073.cpp"                          # arm_neon.h: no such file or directory
rm_file_list+=" i386-10.cpp"                          # isa option -maes -msse2
rm_file_list+=" lambda-uneval9.cc"                    # std=c++2a
rm_file_list+=" pr54300.cpp"                          # arm_neon.h: no such file or directory
rm_file_list+=" arm-neon-1.cpp"                       # arm_neon.h: no such file or directory
rm_file_list+=" nvptx-ptrmem1.cpp"                    # cast lacking at return
rm_file_list+=" o32-fp.cpp"                           # __asm__
rm_file_list+=" check-vect.h"                         # asm
rm_file_list+=" gcov-3.h"                             # Does not build before probing
rm_file_list+=" pr20366.cpp"                          # Does not build before probing
rm_file_list+=" destroying-delete1.cpp"               # Does not build before probing
rm_file_list+=" ppc64-sighandle-cr.cpp"               # ppc asm
rm_file_list+=" asm1.c"                               # junk in file
rm_file_list+=" pr56768.cpp"                          # DMCE_PROBE(TBD), crash?
rm_file_list+=" pr84548.cpp"                          # DMCE_PROBE(TBD), crash?
rm_file_list+=" pr64688-2.cpp"                        # Parser needs info on skip section end, lacking in this case
rm_file_list+=" pr84943-2.cpp"                        # return lack cast
rm_file_list+=" pr64688.cpp"                          # DMCE_PROBE(TBD), crash?
rm_file_list+=" pr58380.cpp"                          # DMCE_PROBE(TBD), crash?
rm_file_list+=" pr63621.cpp"                          # asm
rm_file_list+=" asm5.c"                               # asm
rm_file_list+=" pr85657.cpp"                          # ibm128 not declared...
rm_file_list+=" pr85503.cpp"                          # __builtin_vec_vsx_ld was not declared in this scope
rm_file_list+=" pragma_plugin.c"                      # gcc-plugin.h: no such file or directory
rm_file_list+=" pr78229.cpp"                          # __builtin_ia32_tzcnt_u32’ was not declared in this scope
rm_file_list+=" pr82410.cpp"                          # Need to check for operator call, lambda and initlist, lets skip for now
rm_file_list+=" simd-clone-6.cc"                      # -fopenmp-simd -fno-inline -mavx
rm_file_list+=" simd-clone-4.cc"                      # -fopenmp-simd -fno-inline -mavx
rm_file_list+=" simd-clone-2.cc"                      # -fopenmp-simd -fno-inline -mavx
rm_file_list+=" simd-clone-1.cc"                      # -fopenmp-simd -fno-inline -mavx
rm_file_list+=" pr77844.cpp"                          # Misses simple nested [ and ( why this one?
rm_file_list+=" struct-layout-1_generate.c"           # generate-random.h: No such file or directory
rm_file_list+=" system-binary-constants-1.cpp"        # system-binary-constants-1.h: No such file or directory
rm_file_list+=" structret1.cpp"                       # asm
rm_file_list+=" utf-type-char8_t.cpp"                 # __CHAR8_TYPE__ was not declared in this scope
rm_file_list+=" var-templ1.cpp"                       # Does not build before probing
rm_file_list+=" using57.cpp"                          # return lacks cast
rm_file_list+=" unexpected1_x.cpp"                    # deprecated throw
rm_file_list+=" va-arg-pack-len-1.cpp"                # error directive for vararg checks, lets not dwell here
rm_file_list+=" struct-layout-1_x1.h"                 # No such file or directory
rm_file_list+=" copyprop.cpp"                         # Does not build before probing
rm_file_list+=" varmod1.cpp"                          # Does not build before probing
rm_file_list+=" typeof6.cpp"                          # Does not build before probing
rm_file_list+=" udlit-resolve-char8_t.cpp"            # Does not build before probing
rm_file_list+=" typeof1.cpp"                          # Does not build before probing
rm_file_list+=" visibility-9.cpp"                     # __attribute__((dllimport)) f1();
rm_file_list+=" gcov-3.cpp"                           # gcov-3.h: No such file or directory
rm_file_list+=" simd-2.cpp"                           # check-vect.h: No such file or directory
rm_file_list+=" mangle56.cpp"                         # #include <initializer_list>
rm_file_list+=" pr61034.cpp"                           # transaction safe builtin
rm_file_list+=" new1.cpp"                             # transaction safe builtin
rm_file_list+=" bitfield1.cpp"                        # typedef typeof
rm_file_list+=" simd-5.cpp"                           # simd5 switch
rm_file_list+=" typename12.cpp"                       # a bug (not following standard) in gcc around the comma separator?
rm_file_list+=" typename6.cpp"                        # a bug (not following standard) in gcc around the comma separator?
rm_file_list+=" pr68220.cpp"                          # file not yet examined
rm_file_list+=" pr45572-1.cpp"                        # file not yet examined
rm_file_list+=" pr68388.cpp"                          # file not yet examined
rm_file_list+=" pr67989.cpp"                          # file not yet examined
rm_file_list+=" pr43655.cpp"                          # file not yet examined

if [[ "$numVars" -ne "0" ]]; then
rm_file_list+=" Wunused-var-10.cpp"                   # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" pr43365.cpp"                          # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" pr79377.cpp"                          # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" temp-extend2.cpp"                     # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" spec24.cpp"                           # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" tls-3.cpp"                            # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" pass_y.h"                             # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" initlist90.cpp"                       # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" volatile1.cpp"                        # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" fnname3.cpp"                          # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" cleanup1.cpp"                         # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" addr-const1.cpp"                      # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" dtor3.cpp"                            # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" ctor1.cpp"                            # re-declaration of struct members shows up as ordinary declarations in AST
rm_file_list+=" dtor3.cpp"                            # re-declaration of struct members shows up as ordinary declarations in AST
fi


set +e
for f in $rm_file_list; do
	find -not -path '*.git*' -name $f -exec git rm -- {} \;
done
set -e

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

git commit -m "broken"
git add .dmceconfig
git commit -m "DMCE config"

_echo "launch DMCE"
${dmce_exec_path}/dmce-launcher -n $(git rev-list --all --count) --debug
_echo "compile"
> ${my_work_path}/compile-errors
find -name '*.err' -exec rm {} \;

if [ ! -s "${dmce_work_path}/${PROG_NAME}/workarea/probe-list" ]; then
	echo "error: empty probe-list"
	exit 1
fi

gcc_opts_candidates=""
gcc_opts_candidates+=" -fno-new-ttp-matching"
gcc_opts_candidates+=" -fext-numeric-literals"
gcc_opts_candidates+=" -fpermissive"
gcc_opts_candidates+=" -fgnu-tm"
gcc_opts_candidates+=" -std=c++17"
for opt in $gcc_opts_candidates; do
        if ! gcc $opt |& grep -q 'unrecognized command'; then
                gcc_opts+=" $opt"
        fi
done
echo "gcc options: $gcc_opts"

while read -r f; do
	{
		if ! gcc -w -c $gcc_opts ${f} 2>> "${f}".err; then
			echo ${f} >> ${my_work_path}/compile-errors;
		fi
	} &
done < ${dmce_work_path}/${PROG_NAME}/workarea/probe-list
wait
find -name '*.err' -type f ! -size 0 -exec cat {} \;
errors=$(cat ${my_work_path}/compile-errors | wc -l)
_echo "exit: ${errors}"
exit ${errors}
