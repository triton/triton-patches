#!/usr/bin/env bash

set -o errexit
set -o pipefail

type -P 'git' > /dev/null 2>&1

rootDir="$(dirname "$(readlink -f "${0}")")"
userInput="${1}"

if [ ! -d "${rootDir}" ] ; then
  echo "ERROR: can't find top level directory"
  echo "${rootDir}"
  exit 1
fi

cd "${rootDir}"

if [ -n "$(git diff --cached 2> /dev/null)" ] ; then
  echo "ERROR: please commit staged changes"
  exit 1
fi

commit_patches() {
  local Change
  local -A ChangeList
  local Dir
  local File
  local GitStatusFile
  local -a GitStatusList
  local Key
  local Value

  eval $(
    git status | grep -E 'deleted:|modified:|untracked:' |
      while read GitStatusFile ; do
        echo "GitStatusList+=(\"${GitStatusFile}\")"
      done
  )

  # Uses file name as key and change type as value
  for File in "${GitStatusList[@]}" ; do
    Key="$(
      echo "${File}" |
        awk '{
          for(i=2;i<=NF;i++)
            print $(i)
        }'
    )"
    [ -n "${Key}" ]

    Value="$(
      echo "${File}" |
        awk '{print $1 ; exit}'
    )"
    if [ "${Value}" == 'deleted:' ] ; then
      Value='remove'
    elif [ "${Value}" == 'modified:' ] ; then
      Value='update'
    elif [ "${Value}" == 'untracked:'] ; then
      Value='add'
    else
      echo "ERROR: invalid value: $Value"
      return 1
    fi
    [ -n "${Value}" ]

    if [ "${Key##*.}" != 'patch' ] ; then
      echo "WARNING: file is not a patch ${Key}, not commiting"
    else
      ChangeList+=(
        ["${Key}"]="${Value}"
      )
    fi
  done

  for Change in "${!ChangeList[@]}" ; do
    git add "${Change}"
    git commit -m "$(dirname "${Change}"): ${ChangeList[$Change]} $(basename ${Change})"
  done
}

commit_patches

git push

exit 0
