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
    echo "git repository          $PWD"
    if [ "$oldsha" != "$oldsha_rev" ]; then
	    echo "Old SHA-1               $(printf %-${padding}s $oldsha) ($oldsha_rev)"
    else
	    echo "Old SHA-1               $oldsha"
	    padding=0
    fi
    if [ "$newsha" != "$newsha_rev" ]; then
	    echo "New SHA-1               $(printf %-${padding}s $newsha) ($newsha_rev)"
    else
	    echo "New SHA-1               $newsha"
    fi
    echo "Files examined          $nbr_of_files"
    echo "Files probed            $files_probed"
    echo "Files skipped           $files_skipped"
    echo "Probes inserted         $nbrofprobesinserted"
    if [ $nbrofprobesinserted -ne 0 ]; then
        echo "Probes                  $dmcepath/probe-references.log"
        echo "Expressions             $dmcepath/expr-references.log"
    fi
    echo "DMCE version            $DMCE_VERSION"
    echo "==============================================="
}

function jobcap {
    while true; do
        if [ "$(pgrep -f $1 | wc -l || :)" -lt "100" ]; then
            break
        fi
        sleep 0.5
    done
}

# Usage
if [ $# -ne 5 ]; then
    echo "Usage: $(basename $0) <path to git top> <new commit sha id> <old commit sha id> <old-git-root> <offset>"
    exit 1
fi

# change the output format for the built in bash command 'time'
TIMEFORMAT="real: %3lR user: %3lU sys: %3lS"

quiet_mode() {
    if [ "x$DMCE_QUIET_MODE" != "x" ] && [ "$DMCE_QUIET_MODE" = "true" ]; then
        return 0
    else
        return 1
    fi
}

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

_echo() {
    if quiet_mode; then
        return
    fi
    echo "$(date '+%Y-%m-%d %H:%M:%S'):dmce.sh:$*"
}

progress

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

# Lets go!
_echo "operate on $git_top"
cd $git_top

# directory set up
rm -rf $dmcepath/{old,new,workarea}
mkdir -p $dmcepath/{old,new,workarea}

_echo "ask git to list modified and added files. Saving files here: $dmcepath/latest.cache"
git diff -l99999 --diff-filter=MA --name-status $oldsha $newsha | grep -E '\.c$|\.cpp$|\.cc$|\.h$' | cut -f2 > $dmcepath/latest.cache

# add modified/untracked files
git status --porcelain | cut -c4- | grep -E '\.c$|\.cpp$|\.cc$|\.h$' >> tee -a $dmcepath/latest.cache || :

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
grep -E -v '^#|^$|:' $configpath/dmce.exclude > $dmcepath/workarea/dmce.exclude

if ! quiet_mode; then
    _echo "includes: "
    cat $dmcepath/workarea/dmce.include
    _echo "excludes: "
    cat $dmcepath/workarea/dmce.exclude
fi

progress

grep -f $dmcepath/workarea/dmce.include $dmcepath/latest.cache | grep -vf $dmcepath/workarea/dmce.exclude | cat > $dmcepath/latest.cache.tmp
_echo "$((nbr_of_files - $(wc -l <$dmcepath/latest.cache.tmp))) files excluded. View these files in $dmcepath/files_excluded.log"
comm -23 --nocheck-order $dmcepath/latest.cache $dmcepath/latest.cache.tmp > $dmcepath/files_excluded.log
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

_echo "copy files and dmce-remove-relpaths.sh"
for c_file in $FILE_LIST; do
    {
        if [[ $c_file == */* ]]; then
            newdestdir=$dmcepath/new/${c_file%/*}
        else
            newdestdir=$dmcepath/new
        fi

        mkdir -p $newdestdir
        cp $c_file $newdestdir/

        # If the file does not exist in $oldsha, create an empty file
        if ! [ -e $old_git_dir/${c_file} ]; then
            touch_files+="$dmcepath/old/$c_file $dmcepath/old/$c_file.clang "
        else
            cp -a $old_git_dir/${c_file} $dmcepath/old/$c_file
            echo $c_file >> $dmcepath/workarea/clang-list.old
        fi
    }
done
[ "${touch_files}" != "" ] && touch $touch_files
$binpath/dmce-remove-relpaths.sh $dmcepath/new &
$binpath/dmce-remove-relpaths.sh $dmcepath/old &
wait

FILE_LIST_NEW="${FILE_LIST}"
if [ -e $dmcepath/workarea/clang-list.old ]; then
    FILE_LIST_OLD=""
    while read -r c_file; do
        FILE_LIST_OLD+="$c_file "
    done < $dmcepath/workarea/clang-list.old
fi

progress

_echo "running clang-check"
i=0
for c_file in $FILE_LIST_OLD; do
    eval clang-check $dmcepath/old/$c_file -ast-dump --extra-arg="-fno-color-diagnostics" 2>>$dmcepath/old/clangresults.log > $dmcepath/old/$c_file.clang &
    (( i+=1 ))
    if [ "$i" -gt 500 ]; then
        i=0
        jobcap clang-check
    fi
done

i=0
for c_file in $FILE_LIST_NEW; do
    eval clang-check $dmcepath/new/$c_file -ast-dump --extra-arg="-fno-color-diagnostics" 2>>$dmcepath/new/clangresults.log > $dmcepath/new/$c_file.clang &
    (( i+=1 ))
    if [ "$i" -gt 500 ]; then
        i=0
        jobcap clang-check
    fi
done
wait

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
done

for c_file in $FILE_LIST_NEW; do
    {
        FILE_SIZE=$(stat -c '%s' $dmcepath/new/$c_file.clang)
        [ "$FILE_SIZE" -lt 1048576 ] && exit
        NUM_SPACES=$(tr -cd ' ' < $dmcepath/new/$c_file.clang | wc -c)
        let PERCENTAGE_SPACES=100*$NUM_SPACES/$FILE_SIZE
        [ "${PERCENTAGE_SPACES}" -gt 95 ] && rm -v $dmcepath/new/$c_file.clang && touch $dmcepath/new/$c_file.clang
    } &
done
wait

progress

_echo "preparing clang data: remove hexnumbers"
for c_file in $FILE_LIST; do
    # Replace all hexnumbers and "branches" (in-place) on clang-files
    sed -i -e "s/0x[0-9a-f]*/Hexnumber/g" -e 's/`-/|-/' $dmcepath/old/$c_file.clang &
    sed -i -e "s/0x[0-9a-f]*/Hexnumber/g" -e 's/`-/|-/' -e 's/`-/|-/' $dmcepath/new/$c_file.clang &
done
wait

progress

_echo "remove position dependent stuff (line numbers) from clang output"
for c_file in $FILE_LIST; do
    sed -e "s/<[^>]*>//g"  $dmcepath/old/$c_file.clang > $dmcepath/old/$c_file.clang.filtered &
    sed -e "s/<[^>]*>//g"  $dmcepath/new/$c_file.clang > $dmcepath/new/$c_file.clang.filtered &
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
done
wait

progress

_echo "producing clang diffs"
for c_file in $FILE_LIST; do
    $binpath/create-clang-diff $dmcepath/new/$c_file.clang.filtereddiff &
done

wait

progress

_echo "inserting probes in $git_top"
for c_file in $FILE_LIST; do
    [ ! -e $dmcepath/new/$c_file.clangdiff ] && continue
    touch $dmcepath/new/$c_file.probedata
    $binpath/generate-probefile.py $c_file $c_file.probed $dmcepath/new/$c_file.probedata $dmcepath/new/$c_file.exprdata <$dmcepath/new/$c_file.clangdiff >> $dmcepath/new/$c_file.probegen.log &
done
wait

progress

if ! quiet_mode; then
    find $dmcepath/new -name '*probegen.log' -print0 |  xargs -0 tail -n 1 | sed -e '/^\s*$/d' -e 's/^==> //' -e 's/ <==$//' -e "s|$dmcepath/new/||" | paste - - |  sort -k2 -n -r | awk -F' ' '{printf "%-110s%10.1f ms %10d probes\n", $1, $2, $4}'
fi

_echo "create probe/skip list:"
find $dmcepath/new -name '*.probedata' ! -size 0 | sed "s|$dmcepath/new/||" | sed "s|.probedata$||" > $dmcepath/workarea/probe-list &
find $dmcepath/new -name '*.probedata' -size 0   | sed "s|$dmcepath/new/||" | sed "s|.probedata$||" > $dmcepath/workarea/skip-list &
wait

progress

nbrofprobesinserted=$(find $dmcepath/new/ -name '*.probedata' -type f ! -size 0 -print0 | xargs -0 cat | wc -l)

_echo "update probed files"
if [ -e "$DMCE_PROBE_PROLOG" ]; then
    _echo "Using prolog file: $DMCE_PROBE_PROLOG"
    cat $DMCE_PROBE_PROLOG > $dmcepath/workarea/probe-header
    # size_of_user compensates for the header put first in all source files by DMCE
    size_of_user=$(wc -l<$DMCE_PROBE_PROLOG)
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
    size_of_user=$(wc -l <$dmcepath/workarea/probe-header)
fi

while read -r c_file; do
  {
      # Header
      cat $dmcepath/workarea/probe-header > $dmcepath/workarea/$c_file

      # The probed source file itself
      cat $c_file.probed >> $dmcepath/workarea/$c_file

      # Put the probe in the end
      cat $DMCE_PROBE_SOURCE >> $dmcepath/workarea/$c_file

      # Make copy of original file and replace it with the probed one
      cp $c_file $c_file.dmceoriginal
      cp $dmcepath/workarea/$c_file $c_file

      # remove probed working files from tree
      rm $c_file.probed
  } &
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
    done < $dmcepath/workarea/probe-list
    echo "$files_skipped file(s) skipped"

    if [ "$files_skipped" -gt 0 ]; then
        echo "To view deltas manually:"
        while read -r f; do
        echo "diff -y --suppress-common-lines $dmcepath/old/$f $dmcepath/new/$f"
        if [ -n "${DMCE_VERBOSE_OUTPUT+x}" ]; then
            diff -y --suppress-common-lines $dmcepath/old/$f $dmcepath/new/$f
        fi
        done < $dmcepath/workarea/skip-list
    fi
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
        ((line = line + size_of_user + 1))

        if [ "$nextfile" == "" ]; then
            # First time, create 'sed' expression
            SED_EXP="-e $line""s/DMCE_PROBE(TBD/DMCE_PROBE($probe_nbr/"
        elif [ "$nextfile" == $file ]; then
            # Same file, append 'sed' expression
            SED_EXP+=" -e $line""s/DMCE_PROBE(TBD/DMCE_PROBE($probe_nbr/"
        else
            # Next file, remember sed command
            SED_CMDS+=("$SED_EXP $git_top/$nextfile")

            # Remember 'sed' expression for next file
            SED_EXP="-e $line""s/DMCE_PROBE(TBD/DMCE_PROBE($probe_nbr/"
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
fi

_echo "$(basename "$git_top") summary:"
if [ -n "${DMCE_VERBOSE_OUTPUT+x}" ]; then
    git --no-pager show --stat "$oldsha".."$newsha" --oneline
fi
summary
