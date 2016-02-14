#!/bin/sh

./build.sh && ./bin/dstep foo.h -o foo.d && cat foo.d
