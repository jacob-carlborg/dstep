#!/bin/sh

dvm use 2.057
rdmd -m32 --build-only -ofbin/dstep -L-L. -L-lclang -L-rpath -L. "$@" dstep/driver/DStep.d