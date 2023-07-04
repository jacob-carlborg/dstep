#!/bin/sh

if [ -s "$HOME/.dvm/scripts/dvm" ] ; then
    . "$HOME/.dvm/scripts/dvm" ;
    dvm use ldc-1.32.0
fi

dub build --verror
#rdmd --build-only -debug -gc -ofbin/dstep -Idstack/mambo -Idstack -L-L. -L-lclang -L-ltango -L-rpath -L. "$@" dstep/driver/DStep.d
