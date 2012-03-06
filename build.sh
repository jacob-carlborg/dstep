#!/bin/sh

dvm use 2.058
rdmd -m32 --build-only -debug -gc -ofbin/dstep -L-L. -L-lclang -L-rpath -L. "$@" dstep/driver/DStep.d