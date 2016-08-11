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
  local -A ChangeList
  local Change
  local Dir
  local File
  local -a GitStatusList

  eval $(
    git status | grep -E 'deleted:|modified:|untracked:' |
      while read GitStatusFile ; do
        echo "GitStatusList+=(\"${GitStatusFile}\")"
      done
  )

  # Uses file name as key and change type as value
  for File in "${GitStatusList[@]}" ; do
    key="$(
      echo "${File}" |
        awk '{
          for(i=2;i<=NF;i++)
            print $(i)
        }'
    )"
    echo "mkkey; ${key}"
    [ -n "${key}" ]

    value="$(
      echo "${File}" |
        awk '{print $1 ; exit}'
    )"
    if [ "${value}" == 'deleted:' ] ; then
      value='remove'
    elif [ "${value}" == 'modified:' ] ; then
      value='update'
    elif [ "${value}" == 'untracked:'] ; then
      value='add'
    else
      echo "ERROR: invalid value: $value"
      return 1
    fi
    [ -n "${value}" ]

    if [ "${key##*.}" != 'patch' ] ; then
      echo "WARNING: file is not a patch ${value}, not commiting"
    else
      ChangeList+=(
        ["${key}"]="${value}"
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
