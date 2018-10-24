#!/bin/sh
cd "$(dirname "$0")"

if [ -d "$1" ] ; then
  directory="$1"
elif [ -d "${1:0:1}/$1" ] ; then
  directory="${1:0:1}/$1"
else
  echo "Not a directory"
  exit 1
fi

echo
for file in $(find "$directory${2+/$2}" -type f | sort); do
  echo "    (fetchTritonPatch {"
  echo "      rev = \"$(git rev-parse HEAD)\";"
  echo "      file = \"$file\";"
  echo "      sha256 = \"$(sha256sum $file | awk '{print $1}')\";"
  echo "    })"
done
