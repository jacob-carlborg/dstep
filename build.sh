#!/bin/sh

if [ -s "$HOME/.dvm/scripts/dvm" ] ; then
    . "$HOME/.dvm/scripts/dvm" ;
    dvm use 2.071.1
fi

SOURCES=`find ./dstep ./clang -name \*.d`

DC=${DC:-dmd}
$DC $DFLAGS -g -O -inline -Jresources -L-lclang -ofbin/dstep $SOURCES
