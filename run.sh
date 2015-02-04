#!/bin/sh

./build.sh && ./bin/dstep foo.h -o foo.d -ObjC && foo.d
