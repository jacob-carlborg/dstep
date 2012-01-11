#!/bin/sh

dvm use 2.057
rdmd --build-only -ofbin/dstep -L-L. -L-lclang -L-rpath -L. "$@" dstep/driver/DStep.d