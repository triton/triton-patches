#!/bin/sh

type -P 'git' > /dev/null 2>&1 || exit 1

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

file_modified() {

  local file

  file="${1}"

  if [ -n "$(git ls-files --others --exclude-standard ${file} 2> /dev/null)" ] ; then
    echo 'untracked'
  elif [ -n "$(git ls-files --deleted ${file} 2> /dev/null)" ] ; then
    echo 'removed'
  elif [ -n "$(git ls-files --modified ${file} 2> /dev/null)" ] ; then
    echo 'modified'
  else
    echo 'ignore'
  fi

  return 0

}

commit_file() {

  local file
  local dir
  local fullPath
  local status

  file="$(basename ${1})"
  dir="$(basename "$(dirname "${1}")")"
  fullPath="${1}"
  status="$(file_modified "${fullPath}")"

  if [ "${status}" == 'untracked' ] || \
     [ "${status}" == 'modified' ] || \
     [ "${status}" == 'removed' ] ; then
    echo "git add \"${fullPath}\""
    git add "${fullPath}"
  fi

  if [ "${status}" == 'untracked' ] ; then
    echo "git commit -m \"${dir}: add ${file}\""
    git commit -m "${dir}: add ${file}"
  elif [ "${status}" == 'modified' ] ; then
    echo "git commit -m \"${dir}: updated ${file}\""
    git commit -m "${dir}: updated ${file}"
  elif [ "${status}" == 'removed' ] ; then
    echo "git commit -m \"${dir}: remove ${file}\""
    git commit -m "${dir}: remove ${file}"
  elif [ "${status}" == 'ignore' ] ; then
    return 0
  else
    return 1
  fi

  return 0

}

commit_patches() {

  local file
  local dir
  local del
  local pid

  dir="${1}"

  if [ ! -d "${dir}" ] ; then
    return 1
  fi

  # Make sure we ignore the top level directory
  if [ "${rootDir}" == "${dir}" ] ; then
    return 1
  fi

  # TODO: look for .patch extension
  for file in $(find ${dir} -type f) ; do
    commit_file "${file}"
    pid=$!
    wait ${pid}
  done

  # Remove deleted files
  for del in $(git ls-files --deleted) ; do
    commit_file "${del}" || {
      echo "ERROR: failed to remove: ${del}"
      return 1
    }
  done

  return 0

}

if [ -z "${userInput}" ] ; then
  patchsDir="${rootDir}"
elif [ -d "${rootDir}/${userInput}" ] ; then
  patchsDir="${rootDir}/${userInput}"
else
  echo "ERROR: invalid directory: ${userInput}"
  exit 1
fi

if [ "${rootDir}" == "${patchsDir}" ] ; then
  # TODO: use find to list dirs
  for dir in $(find ${patchsDir} -type d -not -iwholename '*.git*') ; do
    # Make sure we ignore the top level directory
    [ "${dir}" == "${rootDir}" ] && continue
    echo -e "\e[32m${dir}\e[0m"
    commit_patches "${dir}" || true
  done
else
  commit_patches "${patchsDir}" || true
fi

git push

exit 0
