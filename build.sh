#!/bin/sh

if [ -s "$HOME/.dvm/scripts/dvm" ] ; then
    . "$HOME/.dvm/scripts/dvm" ;
fi

dvm use 2.059
rdmd -m32 --build-only -debug -gc -ofbin/dstep -L-L. -L-lclang -L-rpath -L. "$@" dstep/driver/DStep.d