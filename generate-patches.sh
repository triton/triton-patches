#!/bin/sh
cd "$(dirname "$0")"
for file in $(find $1 -type f); do
  echo "    (fetchTritonPatch {"
  echo "      rev = \"$(git rev-parse HEAD)\";"
  echo "      file = \"$file\";"
  echo "      sha256 = \"$(sha256sum $file | awk '{print $1}')\";"
  echo "    })"
done
