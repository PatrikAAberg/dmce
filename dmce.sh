#!/bin/bash -e

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


# Summary
nbr_of_files=0
files_probed=0
files_skipped=0
nbrofprobesinserted=0

function summary
{
  echo "==============================================="
  echo "Files examined          $nbr_of_files"
  echo "Files probed            $files_probed"
  echo "Files skipped           $files_skipped"
  echo "Probes inserted         $nbrofprobesinserted"
  echo "==============================================="
  echo
}

function jobcap {
  while true; do
    [ "$(pgrep -f $1 | wc -l || :)" -lt "100" ] && break || sleep 0.5
  done
 }

# Usage
if [ "$#" -ne 3 ]; then
  echo "Usage: $(basename $0) <path to git top> <new commit sha id> <old commit sha id>"
  exit
fi

# change the output format for the built in bash command 'time'
TIMEFORMAT="done: real: %3lR user: %3lU sys: %3lS"

echo "------"
echo "Init"
echo
time {
  # Variable set up and config
  binpath=$DMCE_EXEC_PATH
  configpath=$DMCE_CONFIG_PATH
  git_project=$(basename $1)
  git_top=$1
  newsha=$2
  oldsha=$3
  dmcepath="$DMCE_WORK_PATH/$git_project"

  echo "binary path             : $binpath"
  echo "configurations file path: $configpath"
  echo "working directory       : $dmcepath"
  echo "lookup hook             : $DMCE_CMD_LOOKUP_HOOK"
  echo "probe c file            : $DMCE_PROBE_SOURCE"
  echo "probe prolog file       : $DMCE_PROBE_PROLOG"
  echo "git path                : $git_top"
  echo "New sha1                : $newsha"
  echo "Old sha1                : $oldsha"

  # Lets go!
  echo "Operate on $git_top"
  cd $git_top

  # directory set up
  rm -rf $dmcepath/{old,new,workarea}
  mkdir -p $dmcepath/{old,new,workarea}

  # pretty print old/new SHA-1
  git_fmt='%h?%ar?%ae?%s'
  echo
  _str="old:?$(git --no-pager log -1 --format=$git_fmt $oldsha)\nnew:?$(git --no-pager log -1 --format=$git_fmt $newsha)"
  echo -e "$_str" | column -t -s? 2> /dev/null
  echo
}

echo "------"
echo "Ask git to list modified and added files. Saving files here: $dmcepath/latest.cache"
echo
time {
  git diff -l99999 --diff-filter=MA --name-status $oldsha $newsha | egrep '\.c$|\.cpp$|\.cc$' | cut -f2 > $dmcepath/latest.cache
  # Add the added and modified files
  git status | grep -oP "[\w\/]+\.c$|[\w\/]+\.cpp$|[\w\/]+\.cc$" >> $dmcepath/latest.cache || :
  # Sanity check
  nbr_of_files=$(wc -l <$dmcepath/latest.cache)
  [ "$nbr_of_files" == "0" ] && echo "error: no modified/added files found, try to increase SHA-1 delta" && ls -l $dmcepath/latest.cache && summary && exit
  echo "git found $nbr_of_files modified and changed files"
}

echo "------"
echo "Updating filecache removing exceptions. "
echo
time {
  # Exclude comments and blank rows
  egrep -v '^#|^$' $configpath/dmce.include > $dmcepath/workarea/dmce.include
  egrep -v '^#|^$' $configpath/dmce.exclude > $dmcepath/workarea/dmce.exclude

  echo "Includes: "
  cat $dmcepath/workarea/dmce.include
  echo
  echo "Excludes: "
  cat $dmcepath/workarea/dmce.exclude
  echo
  grep -f $dmcepath/workarea/dmce.include $dmcepath/latest.cache | grep -vf $dmcepath/workarea/dmce.exclude | cat > $dmcepath/latest.cache.tmp
  echo "$(($nbr_of_files-$(wc -l <$dmcepath/latest.cache.tmp))) files excluded. View these files in $dmcepath/files_excluded.log"
  comm -23 --nocheck-order $dmcepath/latest.cache $dmcepath/latest.cache.tmp > $dmcepath/files_excluded.log
  mv $dmcepath/latest.cache.tmp $dmcepath/latest.cache
  nbr_of_files=$(wc -l <$dmcepath/latest.cache)
  if [ $nbr_of_files -eq 0 ]; then
    echo "error: no files after include and exclude filter"
    summary
    exit
  fi
}

# Populate FILE_LIST
FILE_LIST=""
while read c_file; do
  FILE_LIST+="$c_file "
done < $dmcepath/latest.cache

if [ -z ${DMCE_CMD_LOOKUP_HOOK+x} ]; then
  :
else
  echo "------"
  echo "Producing individual command lines if available"
  echo
  time {
    pushd $configpath &>/dev/null
    [ -e $dmcepath/cmdlookup.cache ] && rm $dmcepath/cmdlookup.cache
    for c_file in $FILE_LIST; do
      $DMCE_CMD_LOOKUP_HOOK $c_file >> $dmcepath/cmdlookup.cache &
    done
    echo "waiting for spawned '$DMCE_CMD_LOOKUP_HOOK' jobs to finish, this may take a while."
    wait
    popd &>/dev/null
    # sanity check
    [ "$(wc -c < $dmcepath/cmdlookup.cache)" == "0" ] && echo "error: cmdlookup.cache is empty" && ls -l $dmcepath/cmdlookup.cache && exit 1

    # remove duplicates
    sort -o $dmcepath/cmdlookup.cache -u $dmcepath/cmdlookup.cache
  }
fi

# No hook, create the json file in here
echo "------"
echo "Producing compile_commands.json files (used by clang-check)"
echo
time {
  declare -A folders=()

  # Creating folder structure
  for c_file in $FILE_LIST; do
    dirname=`dirname ${c_file}`
    [[ "${folders[$dmcepath/new/$dirname]+foobar}" ]]      && continue || folders[$dmcepath/new/$dirname]=1
    [[ "${folders[$dmcepath/old/$dirname]+foobar}" ]]                  || folders[$dmcepath/old/$dirname]=1
    [[ "${folders[$dmcepath/workarea/$dirname]+foobar}" ]]             || folders[$dmcepath/workarea/$dirname]=1
  done

  for i in "${!folders[@]}"; do
    mkdir_cmd+="$i "
  done

  mkdir -p $mkdir_cmd

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
    find $dmcepath/new -name '*.JSON' | xargs cat >> $dmcepath/new/compile_commands.json &
    find $dmcepath/old -name '*.JSON' | xargs cat >> $dmcepath/old/compile_commands.json &
    wait

    # JSON end
    echo ']' >>  $dmcepath/new/compile_commands.json
    echo ']' >>  $dmcepath/old/compile_commands.json
  else
    $binpath/generate-compile-commands.py $dmcepath/new $dmcepath/cmdlookup.cache <$dmcepath/latest.cache| sed -e "s/\$USER/${USER}/g" > $dmcepath/new/compile_commands.json &
    $binpath/generate-compile-commands.py $dmcepath/old $dmcepath/cmdlookup.cache <$dmcepath/latest.cache | sed -e "s/\$USER/${USER}/g" > $dmcepath/old/compile_commands.json &
    wait
  fi
}

echo "------"
echo "Running git cat-file, git show and dmce-remove-relpaths.sh"
echo

time {
  for c_file in $FILE_LIST; do
    {
      # Sanity check that file exist in $newsha
      mkdir -p `dirname $dmcepath/new/${c_file}`
      cp $c_file $dmcepath/new/$c_file
      $binpath/dmce-remove-relpaths.sh $dmcepath/new/$c_file
      echo $c_file >> $dmcepath/workarea/clang-list.new
    } &

    {
      # Always create the path for the old file
      mkdir -p `dirname $dmcepath/old/${c_file}`

      # If the file does not exist in $oldsha, create an empty file
      if ! git cat-file -e $oldsha:$c_file &> /dev/null; then
        touch $dmcepath/old/$c_file $dmcepath/old/$c_file.clang
      else
        git show $oldsha:$c_file > $dmcepath/old/$c_file
        $binpath/dmce-remove-relpaths.sh $dmcepath/old/$c_file
        echo $c_file >> $dmcepath/workarea/clang-list.old
      fi
    } &
  done
  wait

  FILE_LIST_NEW=""
  while read c_file; do
    FILE_LIST_NEW+="$c_file "
  done < $dmcepath/workarea/clang-list.new

  if [ -e $dmcepath/workarea/clang-list.old ]; then
    FILE_LIST_OLD=""
    while read c_file; do
      FILE_LIST_OLD+="$c_file "
    done < $dmcepath/workarea/clang-list.old
  fi
}

echo "------"
echo "Running clang-check"
echo
time {
  i=0
  for c_file in $FILE_LIST_OLD; do
    clang-check $dmcepath/old/$c_file -ast-dump --extra-arg="-fno-color-diagnostics" 2>>$dmcepath/old/clangresults.log > $dmcepath/old/$c_file.clang &
    let 'i = i + 1'
    [ "$i" -gt 500 ] && i=0 && jobcap clang-check
  done

  i=0
  for c_file in $FILE_LIST_NEW; do
    clang-check $dmcepath/new/$c_file -ast-dump --extra-arg="-fno-color-diagnostics" 2>>$dmcepath/new/clangresults.log > $dmcepath/new/$c_file.clang &
    let 'i = i + 1'
    [ "$i" -gt 500 ] && i=0 && jobcap clang-check
  done
  echo "waiting for spawned 'clang-check' jobs to finish, this may take a while."
  wait
}

echo "------"
echo "Remove clang files equal or greather than 1MB that contains more than 95% spaces"
echo
time {
  for c_file in $FILE_LIST_OLD; do
    {
      FILE_SIZE=$(stat -c '%s' $dmcepath/old/$c_file.clang)
      [ "$FILE_SIZE" -lt 1048576 ] && exit
      NUM_SPACES=$(tr -cd ' ' < $dmcepath/old/$c_file.clang | wc -c)
      PERCENTAGE_SPACES=$(bc -l <<< "scale=2;$NUM_SPACES/$FILE_SIZE")
      [ "${PERCENTAGE_SPACES:1:2}" -gt 95 ] && rm -v $dmcepath/old/$c_file.clang && touch $dmcepath/old/$c_file.clang
    } &
  done

  for c_file in $FILE_LIST_NEW; do
    {
      FILE_SIZE=$(stat -c '%s' $dmcepath/new/$c_file.clang)
      [ "$FILE_SIZE" -lt 1048576 ] && exit
      NUM_SPACES=$(tr -cd ' ' < $dmcepath/new/$c_file.clang | wc -c)
      PERCENTAGE_SPACES=$(bc -l <<< "scale=2;$NUM_SPACES/$FILE_SIZE")
      [ "${PERCENTAGE_SPACES:1:2}" -gt 95 ] && rm -v $dmcepath/new/$c_file.clang && touch $dmcepath/new/$c_file.clang
    } &
  done
  echo "waiting for spawned 'stat' jobs to finish, this may take a while."
  wait
}

echo "------"
echo "Preparing clang data: Remove hexnumbers"
echo
time {
  for c_file in $FILE_LIST; do
    # Remove all hexnumbers (in-place) on clang-files
    perl -i -pe 's| 0[xX][0-9a-fA-F]+| Hexnumber|g;' -pe 's#\`-#|-#;' -pe 's#(.*\|-CallExpr.*)#\n$1#;' $dmcepath/old/$c_file.clang $dmcepath/new/$c_file.clang &
  done
  echo "waiting for spawned 'perl' jobs to finish, this may take a while."
  wait
}

echo "------"
echo "Remove position dependent stuff (line numbers etc) from clang output"
echo
time {
  for c_file in $FILE_LIST; do
    perl -pe 's|<.*?>||;' -pe 's|line:[0-9]+:[0-9]+||;' $dmcepath/old/$c_file.clang > $dmcepath/old/$c_file.clang.filtered &
    perl -pe 's|<.*?>||;' -pe 's|line:[0-9]+:[0-9]+||;' $dmcepath/new/$c_file.clang > $dmcepath/new/$c_file.clang.filtered &
  done
  echo "waiting for spawned 'perl' jobs to finish, this may take a while."
  wait
}

echo "------"
echo "Create filtered clang diff"
echo
time {
  for c_file in $FILE_LIST; do
    # Create filtered diff
    git --no-pager diff -U0 $dmcepath/old/$c_file.clang.filtered $dmcepath/new/$c_file.clang.filtered > $dmcepath/new/$c_file.clang.filtereddiff || : &
  done
  echo "waiting for spawned 'git diff' jobs to finish, this may take a while."
  wait
}

echo "------"
echo "Producing clang diffs"
echo
time {
  for c_file in $FILE_LIST; do
    $binpath/create-clang-diff $dmcepath/new/$c_file.clang.filtereddiff &
  done

  echo "waiting for spawned 'create-clang-diff' jobs to finish, this may take a while."
  wait
}

echo "------"
echo "Inserting probes in $git_top"
echo
time {
  for c_file in $FILE_LIST; do
      [ ! -e $dmcepath/new/$c_file.clangdiff ] && continue
      touch $dmcepath/new/$c_file.probedata
      $binpath/generate-probefile.py $c_file $c_file.probed $dmcepath/new/$c_file.probedata $dmcepath/new/$c_file.exprdata $configpath/constructs.exclude <$dmcepath/new/$c_file.clangdiff >> $dmcepath/new/$c_file.probegen.log &
  done
  echo "waiting for spawned 'generate-probefile' jobs to finish, this may take a while."
  wait
  echo
  find $dmcepath/new -name '*probegen.log' |  xargs tail -n 1 | sed -e '/^\s*$/d' -e 's/^==> //' -e 's/ <==$//' -e "s|$dmcepath/new/||" | paste - - |  sort -k2 -n -r | awk -F' ' '{printf "%-110s%10.1f ms %10d probes\n", $1, $2, $4}'
  echo
}

echo "------"
echo "Create probe/skip list:"
echo
time {
  find $dmcepath/new -name '*.probedata' ! -size 0 | sed "s|$dmcepath/new/||" | sed "s|.probedata$||" > $dmcepath/workarea/probe-list &
  find $dmcepath/new -name '*.probedata' -size 0   | sed "s|$dmcepath/new/||" | sed "s|.probedata$||" > $dmcepath/workarea/skip-list &
  wait
}

echo "------"
echo "Update probed files"
echo
time {

  if [ -e "$DMCE_PROBE_PROLOG" ]; then
    echo "Using prolog file: $DMCE_PROBE_PROLOG"
    cat $DMCE_PROBE_PROLOG > $dmcepath/workarea/probe-header
    # size_of_user compensates for the header put first in all source files by DMCE
    size_of_user=$(wc -l<$DMCE_PROBE_PROLOG)
  else
    echo "No prolog file found, using default"
    nbrofprobesinserted=$(find $dmcepath/new/ -name '*.probedata' -type f ! -size 0 | xargs cat | wc -l)
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

  while read c_file; do
    {
      # Header
      cat $dmcepath/workarea/probe-header > $dmcepath/workarea/$c_file

      # The probed source file itself
      cat $c_file.probed >> $dmcepath/workarea/$c_file

      # Put the probe in the end
      cat $DMCE_PROBE_SOURCE >> $dmcepath/workarea/$c_file

      # Make copy of original file and replace it with the probed one
      cp $c_file $c_file.orginal
      cp $dmcepath/workarea/$c_file $c_file

      # remove probed working files from tree
      rm $c_file.probed
    } &
  done < $dmcepath/workarea/probe-list

  # remove skipped working files from tree
  while read c_file; do
    {
      rm $c_file.probed
     } &
  done < $dmcepath/workarea/skip-list

  echo "waiting for spawned 'probe' jobs to finish, this may take a while."
  wait
}

echo "------"
echo "Results:"
echo
time {
  files_probed=$(wc -l <$dmcepath/workarea/probe-list 2> /dev/null )
  files_skipped=$(wc -l <$dmcepath/workarea/skip-list 2> /dev/null)
  echo "$files_probed file(s) probed:"
  while read f; do
    echo "$git_top/$f"
  done < $dmcepath/workarea/probe-list
  echo
  echo "$files_skipped file(s) skipped"

  if [ "$files_skipped" -gt 0 ]; then
    echo "To view deltas manually:"
    while read f; do
      echo "diff -y --suppress-common-lines $dmcepath/old/$f $dmcepath/new/$f"
      if ! [ -z ${DMCE_VERBOSE_OUTPUT+x} ]; then
        diff -y --suppress-common-lines $dmcepath/old/$f $dmcepath/new/$f
      fi
    done < $dmcepath/workarea/skip-list
    echo
  fi
}

if [ "$files_probed" == 0 ]; then
  nbrofprobesinserted=0
else
  echo "------"
  echo "Assemble and assign probes"
  echo
  time {
    # Assign DMCE_PROBE numbers.
    probe_nbr=$offset
    rm -f $dmcepath/probe-references.log
    nextfile=""
    file=""
    # set-up an ordered list with the probe-files
    # we iterate through
    declare -a file_list=()
    while read -r probe; do
      splitArray=(${probe//:/ })
      file=${splitArray[0]}
      line=${splitArray[1]}
      let 'line = line + size_of_user + 1'

      if [ "$nextfile" == "" ]; then
        # First time, create 'sed' expression
        SED_EXP="-e $line""s/DMCE_PROBE(TBD)/DMCE_PROBE($probe_nbr)/"
      elif [ "$nextfile" == $file ]; then
        # Same file, append 'sed' expression
        SED_EXP+=" -e $line""s/DMCE_PROBE(TBD)/DMCE_PROBE($probe_nbr)/"
      else
        # Next file, remember sed command
        SED_CMDS+=("$SED_EXP $git_top/$nextfile")

        # Remember 'sed' expression for next file
        SED_EXP="-e $line""s/DMCE_PROBE(TBD)/DMCE_PROBE($probe_nbr)/"
      fi

      if [ "$file" != "$nextfile" ]; then
        file_list+=( "$file" )
      fi

      nextfile=$file
      echo "$probe_nbr:$file:$line" >> $dmcepath/probe-references.log


      let 'probe_nbr = probe_nbr + 1'
    done <<< "$(find $dmcepath/new/ -name '*.probedata' -type f ! -size 0 | xargs cat)"


    # Aggregate the probe-expression information into <expr-references.log>
    # Loop through the list of files and aggregate the info from
    # all the <$file>.exprdata into a global expr-references.log file
    echo "------"
    echo "Assemble and assign expression index for probes"
    echo
    probe_nbr=$offset
    rm -f $dmcepath/expr-references.log
    for file in "${file_list[@]}"; do
      local_probe_nbr=0

	while read -r exp; do
	  splitArray=(${exp//:/ })
	  # local_probe_nbr=${splitArray[1]}
	  line=${splitArray[1]}
	  exp_index=${splitArray[2]}
	  full_exp=${splitArray[@]:3}
	  let 'line = line + size_of_user + 1'


	  # echo "$probe_nbr:$file:$local_probe_nbr:$exp_index" >> $dmcepath/expr-references.log
	  echo "$probe_nbr:$file:$line:$exp_index:$full_exp" >> $dmcepath/expr-references.log
	  let 'probe_nbr = probe_nbr + 1'
	  let 'local_probe_nbr = local_probe_nbr + 1'

	done  <<< "$(cat $dmcepath/new/${file}.exprdata)"

    done

    # Last file, remember sed command
    SED_CMDS+=("$SED_EXP $git_top/$nextfile")

  }

  echo "------"
  echo "Launch SED jobs"
  echo
  time {
    for var in "${SED_CMDS[@]}"; do
      sed -i ${var} &
    done
    echo "waiting for spawned 'sed' jobs to finish, this may take a while."
    wait

    # Update global dmce probe file, prepend with absolute path to files
    sed -e "s|^|File: $git_top/|" $dmcepath/probe-references.log >> $dmcepath/../global-probe-references.log
  }
fi

# Summary

echo "------"
echo "$(basename $git_top) summary:"
echo
echo $PWD
if ! [ -z ${DMCE_VERBOSE_OUTPUT+x} ]; then
  git --no-pager show --stat $oldsha..$newsha --oneline
fi
summary
