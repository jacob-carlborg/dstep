#!/bin/sh

if [ -s "$HOME/.dvm/scripts/dvm" ] ; then
    . "$HOME/.dvm/scripts/dvm" ;
    dvm use 2.069.2
fi

dub build
#rdmd --build-only -debug -gc -ofbin/dstep -Idstack/mambo -Idstack -L-L. -L-lclang -L-ltango -L-rpath -L. "$@" dstep/driver/DStep.d
