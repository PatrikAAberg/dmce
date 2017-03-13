#!/bin/bash -e

gcc_version=6.3.0

# change the output format for the built in bash command 'time'
PROG_NAME=$(basename $0 .sh)
TIMEFORMAT="$PROG_NAME: real: %3lR user: %3lU sys: %3lS"

function _echo() {
	echo $(date '+%Y-%m-%d %H:%M:%S'):$PROG_NAME:$@:$(uptime)
}

# setup working directory
if [ -e $HOME/.dmceconfig ]; then
	dmce_work_path="$(grep ^DMCE_WORK_PATH: $HOME/.dmceconfig | cut -d: -f2 | envsubst)"
	dmce_exec_path="$(grep ^DMCE_EXEC_PATH: $HOME/.dmceconfig | cut -d: -f2 | envsubst)"
else
	dmce_work_path="/tmp/$USER/dmce"
	dmce_exec_path="$dmce_work_path/test/$PROG_NAME/dmce"
fi

my_test_path=$(dirname $(echo $PWD/$0))
my_work_path="$dmce_work_path/test/$PROG_NAME"
[ -d $my_work_path ] && rm -rf $my_work_path
mkdir -v -p $my_work_path
pushd $my_work_path

# what kind of machine is this?
grep Mem /proc/meminfo || :
nproc || :

if [ ! -e $HOME/.dmceconfig ]; then
	time {
		_echo "fetch DMCE"
		git clone --depth 1 https://github.com/PatrikAAberg/dmce.git
	}
fi

time {
	_echo "fetch GCC"
	wget -q ftp://ftp.gnu.org/gnu/gcc/gcc-$gcc_version/gcc-$gcc_version.tar.bz2
}

time {
	_echo "unpack GCC"
	tar -xf gcc-$gcc_version.tar.bz2 gcc-$gcc_version/gcc/testsuite/$PROG_NAME
}

time {
	_echo "create git"
	cd gcc-$gcc_version/gcc/testsuite/$PROG_NAME

	git init
	git commit -m "empty" --allow-empty
	git add .
	git commit -m "initial commit"

	# broken
	git rm compile/20000120-2.c
	git rm compile/20011119-2.c
	git rm compile/20030305-1.c
	git rm compile/20050215-1.c
	git rm compile/20050215-2.c
	git rm compile/20050215-3.c
	git rm compile/20111209-1.c
	git rm compile/20160205-1.c
	git rm compile/920520-1.c
	git rm compile/920521-1.c
	git rm compile/dll.c
	git rm compile/limits-*.c
	git rm compile/mipscop-1.c
	git rm compile/mipscop-2.c
	git rm compile/mipscop-3.c
	git rm compile/mipscop-4.c
	git rm compile/pr37669.c
	git rm compile/pr46534.c
	git rm compile/pr67143.c
	git rm compile/pr70199.c
	git rm compile/pr70633.c
	git rm execute/20010206-1.c
	git rm execute/fprintf-chk-1.c
	git rm execute/pr19449.c
	git rm execute/pr67714.c
	git rm execute/pr68532.c
	git rm execute/pr71494.c
	git rm execute/printf-chk-1.c
	git rm execute/vfprintf-chk-1.c
	git rm execute/vprintf-chk-1.c
	git rm unsorted/dump-noaddr.c
	git commit -m "broken"

	# add DMCE config and update paths
	cp -v $dmce_exec_path/test/$PROG_NAME/dmceconfig .dmceconfig
	sed -i "s|DMCE_EXEC_PATH:.*|DMCE_EXEC_PATH:$dmce_exec_path|" .dmceconfig
	sed -i "s|DMCE_CONFIG_PATH:.*|DMCE_CONFIG_PATH:$my_test_path|" .dmceconfig
	sed -i "s|DMCE_CMD_LOOKUP_HOOK:.*|DMCE_CMD_LOOKUP_HOOK:$my_test_path/cmdlookuphook.sh|" .dmceconfig
	sed -i "s|DMCE_PROBE_SOURCE:.*|DMCE_PROBE_SOURCE:$my_test_path/dmce-probe-monolith.c|" .dmceconfig
	git add .dmceconfig
	git commit -m "DMCE config"
}

time {
	_echo "launch DMCE"
	$dmce_exec_path/dmce-launcher -n $(git rev-list --all --count)
}

time {
	_echo "compile"
	> $my_work_path/compile-errors
	for f in $(cat $dmce_work_path/$PROG_NAME/workarea/probe-list); do
		{
			if ! gcc -w -c -std=c++11 $f 2>> "$f".err; then
				echo $f >> $my_work_path/compile-errors;
			fi
		} &
	done

	wait

	find -name '*.err' -type f ! -size 0 -exec cat {} \;
}

_echo "results"
find $dmce_work_path -maxdepth 1  -type f -name "dmce-launcher-$PROG_NAME-*" -printf '%T@ %p\n' | sort -nr | head -1 | awk '{print $2}' | xargs tail -v

errors=$(cat $my_work_path/compile-errors | wc -l)
_echo "exit: $errors"
exit $errors
