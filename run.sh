#!/bin/sh

set -eu

./build.sh
./bin/dstep foo.h -o /dev/stdout
