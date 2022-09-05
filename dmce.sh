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

set -e
# Summary
nbr_of_files=0
files_probed=0
files_skipped=0
nbrofprobesinserted=0

function summary {
    local padding

    padding=$(wc -L <<<$(printf "$oldsha\n$newsha\n"))
    echo "==============================================="
    echo "git repository                    $PWD"
    if [ "$oldsha" != "$oldsha_rev" ]; then
            echo "Old SHA-1                         $(printf %-${padding}s $oldsha) ($oldsha_rev)"
    else
            echo "Old SHA-1                         $oldsha"
            padding=0
    fi
    if [ "$newsha" != "$newsha_rev" ]; then
            echo "New SHA-1                         $(printf %-${padding}s $newsha) ($newsha_rev)"
    else
            echo "New SHA-1                         $newsha"
    fi
    echo "Files examined                    $nbr_of_files"
    echo "Files probed                      $files_probed"
    echo "Files skipped                     $files_skipped"
    echo "Probes inserted                   $nbrofprobesinserted"
    if [ $nbrofprobesinserted -ne 0 ]; then
        echo "Probe metadata                    $dmcepath/probe-references.log"
        echo "Probe metadata (original files)   $dmcepath/probe-references-original.log"
        echo "Expressions                       $dmcepath/expr-references.log"
    fi
    echo "DMCE version                      $DMCE_VERSION"
    echo "==============================================="
}

function jobcap {
        if [ ${DMCE_JOBS:?} -eq 0 ]; then
                return
        fi

	while true; do
		mapfile -t job_list < <(jobs -p -r)
		if [ "${#job_list[@]}" -lt "${DMCE_JOBS}" ]; then
			return
		fi
		wait -n || true
	done
}

function memcap {

    let memlimit=$DMCE_MEMORY_LIMIT
    while true; do
        mem=$(free | grep "Mem")
        tot=$(echo $mem | cut -d' ' -f2)
        used=$(echo $mem | cut -d' ' -f3)
        let ntot=$tot
        let nused=$used
        set +e
        let percentused=nused*100/ntot
        set -e
        if [ $percentused -lt $memlimit ]; then
            break
        else
            echo "Memory limit of ${memlimit}% reached (used: ${percentused}%), wait 10s..."
            sleep 10
        fi
    done
}

# Usage
if [ $# -ne 5 ]; then
    echo "Usage: $(basename $0) <path to git top> <new commit sha id> <old commit sha id> <old-git-root> <offset>"
    exit 1
fi

# change the output format for the built in bash command 'time'
TIMEFORMAT="real: %3lR user: %3lU sys: %3lS"

progress_bar() {
    if [ "x$DMCE_PROGRESS" != "x" ] && [ "$DMCE_PROGRESS" = "true" ]; then
        return 0
    else
        return 1
    fi
}

progress() {
    if ! progress_bar; then
        return
    fi
    echo -en ". "
}

if progress_bar; then
    echo "|. . . . . . . . . . . . . . . >|"
    echo -en "|"
fi

progress

if [ "$(type -t _echo)" != "function" ]; then
	echo "error: could not find _echo function"
	exit 1
fi

_echo "init"
# Variable set up and config
binpath=$DMCE_EXEC_PATH
configpath=$DMCE_CONFIG_PATH
git_project=$(basename $1)
git_top=$1
newsha=$2
oldsha=$3
old_git_dir=$4
offset=$5
dmcepath="$DMCE_WORK_PATH/$git_project"

if ! newsha_rev=$(git rev-list -1 ${newsha}); then
        echo "error: could not run 'git rev-list -1 ${newsha}'"
        exit 1
elif ! oldsha_rev=$(git rev-list -1 ${oldsha}); then
        echo "error: could not run 'git rev-list -1 ${oldsha}'"
        exit 1
fi

_echo "binary path: $binpath"
_echo "configurations file path: $configpath"
_echo "working directory: $dmcepath"
_echo "lookup hook: $DMCE_CMD_LOOKUP_HOOK"
_echo "probe c file: $DMCE_PROBE_SOURCE"
_echo "probe prolog file: $DMCE_PROBE_PROLOG"
_echo "git path: $git_top"
_echo "new sha1: $newsha ($newsha_rev)"
_echo "old sha1: $oldsha ($oldsha_rev)"
_echo "old git dir: $old_git_dir"

[ ! -e "$DMCE_PROBE_SOURCE" ] && echo "Error: Could not find probe: ${DMCE_PROBE_SOURCE}" && exit 1
[ ! -e "$DMCE_PROBE_PROLOG" ] && echo "Error: Could not find prolog: ${DMCE_PROBE_PROLOG}" && exit 1
[ ! -e "$DMCE_CMD_LOOKUP_HOOK" ] && echo "Error: Could not find lookup hook: ${DMCE_CMD_LOOKUP_HOOK}" && exit 1

# AST cache
if [ "$DMCE_AST_CACHE" = true ]; then
    if [ "$DMCE_AST_CACHE_COMPRESS" != "false" ] && [ "$DMCE_AST_CACHE_COMPRESS" != "true" ]; then
        echo "error: DMCE_AST_CACHE_COMPRESS has none valid value: $DMCE_AST_CACHE_COMPRESS"
        exit 1
    fi

    clang_check_md5=$(md5sum $(readlink -f $(command -v clang-check)))
    clang_check_md5=${clang_check_md5%% *};
    ast_cache="$dmcepath/cache/clang/$clang_check_md5"
    mkdir -p $ast_cache
    ast_cache_files=$(find $ast_cache -type f | wc -l)
    _echo "local AST cache '$ast_cache' contains $ast_cache_files files"

    # sanity check AST cache
    if [ $ast_cache_files -ne 0 ]; then
        _echo "sanity check AST cache"
        a=$(find $ast_cache -type f | head -1 | xargs file)
        if  [ "$DMCE_AST_CACHE_COMPRESS" = true ] && [[ "$a" != *"XZ compressed data" ]]; then
            echo "error: the AST cache is not compressed and you want to run with compression. AST cache: $ast_cache"
            echo "info: either run without compression 'DMCE_AST_CACHE_COMPRESS=false' or 'rm -rf $ast_cache'"
            exit 1
        elif [ "$DMCE_AST_CACHE_COMPRESS" = false ] && [[ "$a" == *"XZ compressed data" ]]; then
            echo "error: the AST cache is compressed and you want to run without compression. AST cache: $ast_cache"
            echo "info: either run with compression 'DMCE_AST_CACHE_COMPRESS=true' or 'rm -rf $ast_cache'"
            exit 1
        fi
    fi
fi

# Lets go!
_echo "operate on $git_top"
cd $git_top

# directory set up
rm -rf $dmcepath/{old,new,workarea}
mkdir -p $dmcepath/{old,new,workarea,cache}

c="${dmcepath}/cache/${oldsha_rev}-${newsha_rev}"
# check if we have this interval in our cache
if [ -e "$c" ] && [ "x$(tail -1 "${c}" | cut -d':' -f1)" = "xDMCE" ]; then
    _echo "using file cache '$c'"
    cp -a "${c}" "$dmcepath/latest.cache"
    # remove watermark
    sed -i '$ d' $dmcepath/latest.cache
else
    _echo "ask git to list modified and added files. Saving files here: $dmcepath/latest.cache"
    git diff -l99999 --diff-filter=MA --name-status $oldsha $newsha | grep -E '\.c$|\.cpp$|\.cc$|\.h$' | cut -f2 > "$dmcepath/latest.cache"
    cp -a "$dmcepath/latest.cache" "${c}"
    # add watermark
    echo "DMCE: $(date '+%Y-%m-%d %H:%M:%S')" >> "${c}"
fi

# add modified/untracked files
git status -u --porcelain | cut -c4- | grep -E '\.c$|\.cpp$|\.cc$|\.h$' >> $dmcepath/latest.cache || :

if [ "${DMCE_PROBE_ALL}" -eq 1 ]; then
    git show -l99999 --diff-filter=MA --name-status $oldsha | grep -E '\.c$|\.cpp$|\.cc$|\.h$' | cut -f2 >> $dmcepath/latest.cache
fi

# uniq
sort -o $dmcepath/latest.cache -u $dmcepath/latest.cache

# Sanity check
nbr_of_files=$(wc -l <$dmcepath/latest.cache)

if [ $nbr_of_files -eq 0 ]; then
    echo "error: no modified/added files found, try to increase SHA-1 delta"
    ls -l $dmcepath/latest.cache
    summary
    exit 1
fi

_echo "git found $nbr_of_files modified and added files"

progress

_echo "updating filecache removing exceptions. "
# Exclude comments and blank rows, dont care about eventual function names for include
grep -E -v '^#|^$' $configpath/dmce.include | cut -d':' -f1 > $dmcepath/workarea/dmce.include

# Exclude comments, blank rows and file:function lines for exclude
grep -E -v '^#|^$|:' $configpath/dmce.exclude > $dmcepath/workarea/dmce.exclude || :

if ! quiet_mode; then
    _echo "includes: "
    cat $dmcepath/workarea/dmce.include
    _echo "excludes: "
    cat $dmcepath/workarea/dmce.exclude
fi

progress

grep -f $dmcepath/workarea/dmce.include $dmcepath/latest.cache | grep -vf $dmcepath/workarea/dmce.exclude | cat > $dmcepath/latest.cache.tmp
comm -23 --nocheck-order $dmcepath/latest.cache $dmcepath/latest.cache.tmp > $dmcepath/files_excluded.log
if [ ! -s "$dmcepath/files_excluded.log" ]; then
    _echo "0 files excluded"
else
    _echo "$((nbr_of_files - $(wc -l <$dmcepath/latest.cache.tmp))) files excluded. View these files in $dmcepath/files_excluded.log"
fi
mv $dmcepath/latest.cache.tmp $dmcepath/latest.cache
nbr_of_files=$(wc -l <$dmcepath/latest.cache)
if [ $nbr_of_files -eq 0 ]; then
    echo "error: no files after include and exclude filter"
    summary
    exit 1
fi

progress

# Populate FILE_LIST
FILE_LIST=""
while read -r c_file; do
    # ignore file names with spaces
    if [[ "$c_file" == *" "* ]]; then
        _echo "ignore '$c_file' as it contains one or more spaces"
        continue
    fi
    [ -e $c_file ] || continue
    FILE_LIST+="$c_file "
done < $dmcepath/latest.cache

if [ -z ${DMCE_CMD_LOOKUP_HOOK+x} ]; then
    :
else
    _echo "producing individual command lines if available"
    pushd $configpath &>/dev/null
    [ -e $dmcepath/cmdlookup.cache ] && rm $dmcepath/cmdlookup.cache
    for c_file in $FILE_LIST; do
        $DMCE_CMD_LOOKUP_HOOK $c_file >> $dmcepath/cmdlookup.cache &
        jobcap
    done
    wait
    popd &>/dev/null
    # sanity check
    if [ "$(wc -c < $dmcepath/cmdlookup.cache)" = "0" ]; then
        echo "error: cmdlookup.cache is empty"
        ls -l $dmcepath/cmdlookup.cache
        exit 1
    fi

    # remove duplicates
    sort -o $dmcepath/cmdlookup.cache -u $dmcepath/cmdlookup.cache
fi

progress

# No hook, create the json file in here
_echo "producing compile_commands.json files (used by clang-check)"
declare -A folders=()

# Creating folder structure
for c_file in $FILE_LIST; do
    if [[ ! "${c_file}" == */* ]]; then
        continue
    fi
    dirname=${c_file%/*}
    [[ "${folders[$dmcepath/new/$dirname]+foobar}" ]]      && continue || folders[$dmcepath/new/$dirname]=1
    [[ "${folders[$dmcepath/old/$dirname]+foobar}" ]]                  || folders[$dmcepath/old/$dirname]=1
    [[ "${folders[$dmcepath/workarea/$dirname]+foobar}" ]]             || folders[$dmcepath/workarea/$dirname]=1
done

if [ ${#folders[@]} -ne 0 ]; then
    mkdir -p "${!folders[@]}"
fi

if [ -z ${DMCE_CMD_LOOKUP_HOOK+x} ]; then
    for c_file in $FILE_LIST; do
        # Is this needed? Maybe optimize the gen script instead
        #TODO: Check for c or c++
        #TODO: Add -I.../inc/new and -I.../inc/old directives
        echo -e "{\n\"directory\": \"$dmcepath/new/\",\n\"command\": \"$DMCE_DEFAULT_C_COMMAND_LINE $c_file\",\n\"file\": \"$c_file\"\n}," > $dmcepath/new/"$c_file".JSON &
        echo -e "{\n\"directory\": \"$dmcepath/old/\",\n\"command\": \"$DMCE_DEFAULT_C_COMMAND_LINE $c_file\",\n\"file\": \"$c_file\"\n}," > $dmcepath/old/"$c_file".JSON &
        jobcap
    done
    wait

    # JSON start
    echo '[' >  $dmcepath/new/compile_commands.json
    echo '[' >  $dmcepath/old/compile_commands.json

    # Assemble json files
    find $dmcepath/new -name '*.JSON' -print0 | xargs -0 cat >> $dmcepath/new/compile_commands.json &
    find $dmcepath/old -name '*.JSON' -print0 | xargs -0 cat >> $dmcepath/old/compile_commands.json &
    wait

    # JSON end
    echo ']' >>  $dmcepath/new/compile_commands.json
    echo ']' >>  $dmcepath/old/compile_commands.json
else
    true ${DMCE_DEFAULT_C_COMMAND_LINE:?}
    true ${DMCE_DEFAULT_CPP_COMMAND_LINE:?}
    true ${DMCE_DEFAULT_H_COMMAND_LINE:?}

    $binpath/generate-compile-commands.py $dmcepath/new $dmcepath/cmdlookup.cache <$dmcepath/latest.cache| sed -e "s/\$USER/${USER}/g" > $dmcepath/new/compile_commands.json &
    $binpath/generate-compile-commands.py $dmcepath/old $dmcepath/cmdlookup.cache <$dmcepath/latest.cache | sed -e "s/\$USER/${USER}/g" > $dmcepath/old/compile_commands.json &
    wait
fi

progress

_echo "copy files"
for c_file in $FILE_LIST; do
    {
        if [[ $c_file == */* ]]; then
            newdestdir=$dmcepath/new/${c_file%/*}
        else
            newdestdir=$dmcepath/new
        fi

        cp $c_file $newdestdir/
    } &
    jobcap
done
wait

> $dmcepath/workarea/clang-list.old
for c_file in $FILE_LIST; do
    # Probe the entire history? Just create an empty clang file
    if [ "${DMCE_PROBE_ALL}" -eq 1 ]; then
        touch_files+="$dmcepath/old/$c_file.clang "
    # c_file does not exist in $oldsha, create an empty file AND clang file
    elif ! [ -e $old_git_dir/${c_file} ]; then
        touch_files+="$dmcepath/old/$c_file $dmcepath/old/$c_file.clang "
    else
        cp -a $old_git_dir/${c_file} $dmcepath/old/$c_file &
        echo $c_file >> $dmcepath/workarea/clang-list.old
    fi
    jobcap
done
wait

_echo "touch files"
if [ "x${touch_files}" != "x" ]; then
    printf "%s\n" "$touch_files" | xargs touch
fi

_echo "dmce-remove-relpaths.sh"
$binpath/dmce-remove-relpaths.sh $dmcepath/new &
$binpath/dmce-remove-relpaths.sh $dmcepath/old &
wait

FILE_LIST_NEW="${FILE_LIST}"
if [ -s $dmcepath/workarea/clang-list.old ]; then
    FILE_LIST_OLD=""
    while read -r c_file; do
        FILE_LIST_OLD+="$c_file "
    done < $dmcepath/workarea/clang-list.old
fi

progress

# $1: _file
function run_clang {
    local _base
    local _file

    _file="$1"
    if [ "$DMCE_AST_CACHE" = true ]; then
        md5=$(md5sum $_file)
        md5=${md5%% *};
        md5_s=${md5:0:2}
        _base="${_file/$dmcepath}"
        # remove first component "/new/" or "/old/"
        _base=${_base#*/}
        _base=${_base#*/}
        md5_e=${md5:2}_${_base//\//_}
    fi

    if [ "$DMCE_AST_CACHE" = true ] && [ -d $ast_cache/$md5_s ] && [ -s $ast_cache/$md5_s/$md5_e ]; then
        ext=
        if [ "$DMCE_AST_CACHE_COMPRESS" = true ]; then
            ext=".xz"
        fi
        cp -a $ast_cache/$md5_s/$md5_e $_file.clang${ext}
    else
        eval clang-check $_file -ast-dump --extra-arg="-fno-color-diagnostics" 2> /dev/null > $_file.clang || true
        if [ "$DMCE_AST_CACHE" = true ]; then
            mkdir -p $ast_cache/$md5_s
            if [ "$DMCE_AST_CACHE_COMPRESS" = true ]; then
                xz -c --keep $_file.clang > $ast_cache/$md5_s/$md5_e
            else
                cp -a $_file.clang $ast_cache/$md5_s/$md5_e
            fi
        fi
    fi
}

_echo "running clang-check (old)"
for c_file in $FILE_LIST_OLD; do
    run_clang $dmcepath/old/$c_file &
    jobcap
done
wait

_echo "running clang-check (new)"
for c_file in $FILE_LIST_NEW; do
    run_clang $dmcepath/new/$c_file &
    jobcap
done
wait

if [ "$DMCE_AST_CACHE" = true ] && [ "$DMCE_AST_CACHE_COMPRESS" = true ]; then
    ff=$(find $dmcepath/new $dmcepath/old -type f -name '*.xz' -print)
    if [ "x$ff" != "x" ]; then
        for c_file in $ff; do
            xz -d $c_file &
            jobcap
        done
    fi
    wait
fi

progress

_echo "remove clang files equal or greater than 1MB that contains more than 95% spaces"
for c_file in $FILE_LIST_OLD; do
    {
        FILE_SIZE=$(stat -c '%s' $dmcepath/old/$c_file.clang)
        [ "$FILE_SIZE" -lt 1048576 ] && exit
        NUM_SPACES=$(tr -cd ' ' < $dmcepath/old/$c_file.clang | wc -c)
        let PERCENTAGE_SPACES=100*$NUM_SPACES/$FILE_SIZE
        [ "${PERCENTAGE_SPACES}" -gt 95 ] && rm -v $dmcepath/old/$c_file.clang && touch $dmcepath/old/$c_file.clang
    } &
    jobcap
done

for c_file in $FILE_LIST_NEW; do
    {
        FILE_SIZE=$(stat -c '%s' $dmcepath/new/$c_file.clang)
        [ "$FILE_SIZE" -lt 1048576 ] && exit
        NUM_SPACES=$(tr -cd ' ' < $dmcepath/new/$c_file.clang | wc -c)
        let PERCENTAGE_SPACES=100*$NUM_SPACES/$FILE_SIZE
        [ "${PERCENTAGE_SPACES}" -gt 95 ] && rm -v $dmcepath/new/$c_file.clang && touch $dmcepath/new/$c_file.clang
    } &
    jobcap
done
wait

progress

# Replace all hexnumbers and "branches" (in-place) on clang-files
_echo "preparing clang data: remove hexnumbers (old)"
for c_file in $FILE_LIST; do
    sed -i -e "s/0x[0-9a-f]*/Hexnumber/g" -e 's/`-/|-/' $dmcepath/old/$c_file.clang &
    jobcap
done
_echo "preparing clang data: remove hexnumbers (new)"
for c_file in $FILE_LIST; do
    # uncomment to save a copy of the raw ast file
    #cp $dmcepath/new/$c_file.clang $dmcepath/new/$c_file.ast
    sed -i -e "s/0x[0-9a-f]*/Hexnumber/g" -e 's/`-/|-/' -e 's/`-/|-/' $dmcepath/new/$c_file.clang &
    jobcap
done
wait

progress

_echo "remove position dependent stuff (line numbers) from clang output (old)"
for c_file in $FILE_LIST; do
    sed -e "s/<[^>]*>//g"  $dmcepath/old/$c_file.clang > $dmcepath/old/$c_file.clang.filtered &
    jobcap
done

_echo "remove position dependent stuff (line numbers) from clang output (new)"
for c_file in $FILE_LIST; do
    sed -e "s/<[^>]*>//g"  $dmcepath/new/$c_file.clang > $dmcepath/new/$c_file.clang.filtered &
    jobcap
done
wait

progress

_echo "create filtered clang diff"
for c_file in $FILE_LIST; do
    # Create filtered diff
    git --no-pager diff \
      --diff-algorithm=${DMCE_GIT_DIFF_ALGORITHM:?} \
      -U0 \
      $dmcepath/old/$c_file.clang.filtered \
      $dmcepath/new/$c_file.clang.filtered > $dmcepath/new/$c_file.clang.filtereddiff || : &
    jobcap
done
wait

if [ "$DMCE_DEBUG" = false ]; then
    rm_files=
    for c_file in $FILE_LIST; do
        if [ -e "$dmcepath/new/$c_file.clang.filtered" ]; then
            rm_files+=" $dmcepath/new/$c_file.clang.filtered"
        fi
        if [ -e "$dmcepath/old/$c_file.clang.filtered" ]; then
            rm_files+=" $dmcepath/old/$c_file.clang.filtered"
        fi
    done

    if [ "x$rm_files" != "x" ]; then
        _echo "removing files: clang.filtered"
        printf "%s\n" "$rm_files" | xargs rm
    fi
fi

progress

_echo "producing clang diffs"
for c_file in $FILE_LIST; do
    $binpath/create-clang-diff $dmcepath/new/$c_file.clang.filtereddiff &
    jobcap
done

wait

if [ "$DMCE_DEBUG" = false ]; then
    rm_files=
    for c_file in $FILE_LIST; do
        if [ -e "$dmcepath/new/$c_file.clang.filtereddiff" ]; then
            rm_files+=" $dmcepath/new/$c_file.clang.filtereddiff"
        fi
        if [ -e "$dmcepath/new/$c_file.clang" ]; then
            rm_files+=" $dmcepath/new/$c_file.clang"
        fi
        if [ -e "$dmcepath/old/$c_file.clang" ]; then
            rm_files+=" $dmcepath/old/$c_file.clang"
        fi
    done

    if [ "x$rm_files" != "x" ]; then
        _echo "removing files: clang and clang.filtereddiff"
        printf "%s\n" "$rm_files" | xargs rm
    fi
fi

progress

_echo "inserting probes in $git_top"
for c_file in $FILE_LIST; do
    if [ ! -e $dmcepath/new/$c_file.clangdiff ]; then
        continue
    fi
    touch $dmcepath/new/$c_file.probedata
    cmd="$binpath/generate-probefile.py $c_file $c_file.probed $dmcepath/new/$c_file.probedata $dmcepath/new/$c_file.exprdata <$dmcepath/new/$c_file.clangdiff"
    if [ "$DMCE_DEBUG" = true ]; then
        eval $cmd > $dmcepath/new/$c_file.probegen.log &
    else
        eval $cmd > /dev/null &
    fi
    jobcap
    memcap
done
wait

if [ "$DMCE_DEBUG" = false ]; then
    rm_files=
    for c_file in $FILE_LIST; do
        if [ -e "$dmcepath/new/$c_file.clangdiff" ]; then
            rm_files+=" $dmcepath/new/$c_file.clangdiff"
        fi
    done
    if [ "x$rm_files" != "x" ]; then
        _echo "removing files: clangdiff"
        printf "%s\n" "$rm_files" | xargs rm || true
    fi
elif ! quiet_mode; then
    find $dmcepath/new -name '*probegen.log' -print0 |  xargs -0 tail -n 1 | sed -e '/^\s*$/d' -e 's/^==> //' -e 's/ <==$//' -e "s|$dmcepath/new/||" | paste - - |  sort -k2 -n -r | awk -F' ' '{printf "%-110s%10.1f ms %10d probes\n", $1, $2, $4}'
fi

progress

_echo "create probe/skip list:"
find $dmcepath/new -name '*.probedata' ! -size 0 | sed "s|$dmcepath/new/||" | sed "s|.probedata$||" > $dmcepath/workarea/probe-list &
find $dmcepath/new -name '*.probedata' -size 0   | sed "s|$dmcepath/new/||" | sed "s|.probedata$||" > $dmcepath/workarea/skip-list &
wait

# if struct parsing enabled, do not skip anything
if [ "X${DMCE_STRUCTS}" != "X" ]; then
    cat $dmcepath/workarea/skip-list >> $dmcepath/workarea/probe-list
    rm -f $dmcepath/workarea/skip-list
    touch $dmcepath/workarea/skip-list
    size_of_user=1
else
    size_of_user=0
fi

progress

nbrofprobesinserted=$(find $dmcepath/new/ -name '*.probedata' -type f ! -size 0 -print0 | xargs -0 cat | wc -l)

_echo "update probed files"
if [ -e "$DMCE_PROBE_PROLOG" ]; then
    _echo "using prolog file: $DMCE_PROBE_PROLOG"
    cat $DMCE_PROBE_PROLOG > $dmcepath/workarea/probe-header
    # size_of_user compensates for the header put first in all source files by DMCE
    ((size_of_user = size_of_user + $(wc -l<$DMCE_PROBE_PROLOG)))
else
    cat > $dmcepath/workarea/probe-header << EOF
#ifndef __DMCE_PROBE_FUNCTION__HEADER__
#define __DMCE_PROBE_FUNCTION__HEADER__
static void dmce_probe_body(unsigned int probenbr);
#define DMCE_NBR_OF_PROBES (${nbrofprobesinserted})
#define DMCE_PROBE(a) (dmce_probe_body(a))
#endif
EOF
    # size_of_user compensates for the header put first in all source files by DMCE
    ((size_of_user = size_of_user + $(wc -l <$dmcepath/workarea/probe-header)))
fi

while read -r c_file; do
  {
      # Header
      cat $dmcepath/workarea/probe-header > $dmcepath/workarea/$c_file

      # The probed source file itself
      cat $c_file.probed >> $dmcepath/workarea/$c_file

      # new line
      echo "" >> $dmcepath/workarea/$c_file

      # any defines from the config file
      if [ -s $dmcepath/probedefines.h ]; then
              cat $dmcepath/probedefines.h >> $dmcepath/workarea/$c_file
      fi

      # built-in defines

      echo "#define DMCE_NBR_OF_PROBES (${nbrofprobesinserted})" >> $dmcepath/workarea/$c_file

      # Put the probe in the end
      cat $DMCE_PROBE_SOURCE >> $dmcepath/workarea/$c_file

      # Make copy of original file and replace it with the probed one
      cp $c_file $c_file.dmceoriginal
      cp $dmcepath/workarea/$c_file $c_file

      # remove probed working files from tree
      rm $c_file.probed
  } &
  jobcap
done < $dmcepath/workarea/probe-list

# remove skipped working files from tree
xargs rm 2> /dev/null <<<"$(sed -e 's/$/.probed/g' $dmcepath/workarea/skip-list)" || :

wait

if progress_bar; then
    echo ">|"
fi

_echo "results:"
files_probed=$(wc -l <$dmcepath/workarea/probe-list 2> /dev/null )
files_skipped=$(wc -l <$dmcepath/workarea/skip-list 2> /dev/null)
if ! quiet_mode; then
    echo "$files_probed file(s) probed:"
    while read -r f; do
        echo "$git_top/$f"
    done < $dmcepath/workarea/probe-list | sort | cat -n
    echo "$files_skipped file(s) skipped:"
    while read -r f; do
        echo "$git_top/$f"
    done < $dmcepath/workarea/skip-list | sort | cat -n
fi

if [ -f "$dmcepath/probe-references.log" ]; then
       rm -f "$dmcepath/probe-references.log"
fi

if [ -f "$dmcepath/expr-references.log" ]; then
       rm -f "$dmcepath/expr-references.log"
fi

if [ "$files_probed" == 0 ]; then
    nbrofprobesinserted=0
else
    _echo "assemble and assign probes"
    # Assign DMCE_PROBE numbers.
    probe_nbr=$offset
    nextfile=""
    file=""
    # set-up an ordered list with the probe-files
    # we iterate through
    declare -a file_list=()
    declare -a str=()
    while IFS=':' read -r file line func; do
        ((line = line + size_of_user + 1)) # compensate for prolog and extra #include line

        if [ "$nextfile" == "" ]; then
            # First time, create 'sed' expression
            SED_EXP="-e $line""s/DMCE_PROBE\([0-9]*\)(TBD/DMCE_PROBE\1($probe_nbr/"
        elif [ "$nextfile" == $file ]; then
            # Same file, append 'sed' expression
            SED_EXP+=" -e $line""s/DMCE_PROBE\([0-9]*\)(TBD/DMCE_PROBE\1($probe_nbr/"
        else
            # Next file, remember sed command
            SED_CMDS+=("$SED_EXP $git_top/$nextfile")

            # Remember 'sed' expression for next file
            SED_EXP="-e $line""s/DMCE_PROBE\([0-9]*\)(TBD/DMCE_PROBE\1($probe_nbr/"
        fi

        if [ "$file" != "$nextfile" ]; then
            file_list+=( "$file" )
        fi

        nextfile=$file
        str+=("$probe_nbr:$file:$line:$func")

        ((probe_nbr = probe_nbr + 1))
    done <<< "$(find $dmcepath/new/ -name '*.probedata' -type f ! -size 0 -print0 | xargs -0 cat)"

    printf "%s\n" ${str[*]} > "$dmcepath/probe-references.log" &

    # Last file, remember sed command
    SED_CMDS+=("$SED_EXP $git_top/$nextfile")

    _echo "launch SED jobs"
    for var in "${SED_CMDS[@]}"; do
        sed -i ${var} &
        jobcap
    done
    wait

    # Update global dmce probe file, prepend with absolute path to files
    sed -e "s|^|File: $git_top/|" $dmcepath/probe-references.log >> $dmcepath/../global-probe-references.log

    # Aggregate the probe-expression information into <expr-references.log>
    # Loop through the list of files and aggregate the info from
    # all the <$file>.exprdata into a global expr-references.log file
    _echo "assemble and assign expression index for probes"
    probe_nbr=$offset
    declare -a str=()
    for file in "${file_list[@]}"; do
        while IFS=: read -r nop line exp_index full_exp; do
            echo $nop > /dev/null
            ((line = line + size_of_user + 1))
            str+=("$probe_nbr:$file:$line:$exp_index:$full_exp")
            (( probe_nbr+=1 ))
        done <$dmcepath/new/${file}.exprdata
    done

    for ((i = 0; i < ${#str[@]}; i++)); do
        echo "${str[$i]}" >> "$dmcepath/expr-references.log"
    done

    # Create a probe ref file with original line numbers
    cat $dmcepath/probe-references.log | sed -e "s/:/ /g" | awk -v len="$size_of_user" '{printf $1 " " $2 " " $3 - len " " $4; $1=$2=$3=$3=$4=""; print}' | sed -e "s/  */:/g" | sed -e "s/:*$//" > $dmcepath/probe-references-original.log
fi

_echo "$(basename "$git_top") summary:"
summary
