#!/bin/sh

set -e

cd "$DUB_PACKAGE_DIR"

if [ -d .git ]; then
  git describe --tags > resources/VERSION
else
  echo 'unknown' > resources/VERSION
fi
