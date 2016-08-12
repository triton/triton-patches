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

if [ -n "$(git diff --cached 2>&-)" ] ; then
  echo "ERROR: please commit staged changes"
  exit 1
fi

color_term() {
  # Colorize output
  case "${1}" in
    'add') echo '\e[32m' ;;
    'remove') echo '\e[31m' ;;
    'update') echo '\e[33m' ;;
  esac
}

commit_patches() {
  local SkipFile=false
  local -A ChangeList
  local File
  local GitCommitMessage
  local GitDeletedFile
  local -a GitDeletedFiles
  local GitModifiedFile
  local GitUntrackedFile

  # Deleted Files
  while read GitDeletedFile ; do
    # Store deleted files for filtering out from modified
    GitDeletedFiles+=("${GitDeletedFile}")
    ChangeList+=(["${GitDeletedFile}"]='remove')
  done < <(git ls-files --deleted)

  # Modified files
  while read GitModifiedFile ; do
    # Make sure SkipFile is reset at the beginning of an iteration
    SkipFile=false
    # Git recognizes deleted files as modified so filter them out
    for GitDeleted in "${GitDeletedFiles[@]}" ; do
      if [ "${GitModifiedFile}" == "${GitDeleted}" ] ; then
        SkipFile=true
      fi
    done
    if ${SkipFile} ; then
      continue
    fi
    ChangeList+=(["${GitModifiedFile}"]='update')
  done < <(git ls-files --modified)

  # Untracked files
  while read GitUntrackedFile ; do
    ChangeList+=(["${GitUntrackedFile}"]='add')
  done < <(git ls-files --others --exclude-standard)

  for File in "${!ChangeList[@]}" ; do
    # Only commit files with a .patch extension
    if [ "${File##*.}" == 'patch' ] ; then
      git add "${File}"
      GitCommitMessage="$(dirname "${File}"): ${ChangeList[$File]} $(basename ${File})"
      echo -e "$(color_term "${ChangeList[$File]}")${GitCommitMessage}\e[0m"
      git commit -m "${GitCommitMessage}" > /dev/null
    else
      echo "WARNING: \`${File}\` is not a patch, not commiting"
    fi
  done

  git push
}

pushd "${rootDir}" > /dev/null
  commit_patches
popd > /dev/null

exit 0
