#!/bin/sh

if [ -s "$HOME/.dvm/scripts/dvm" ] ; then
    . "$HOME/.dvm/scripts/dvm" ;
    dvm use 2.063.2
fi

rdmd -m32 --build-only -debug -gc -ofbin/dstep -Idstack/mambo -Idstack -L-L. -L-lclang -L-ltango -L-rpath -L. "$@" dstep/driver/DStep.d
