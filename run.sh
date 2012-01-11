#!/bin/sh

./build.sh

if [ "$?" = 0 ] ; then
  ./bin/dstep "$@"
fi