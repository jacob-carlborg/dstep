#!/bin/sh

if [ -s "$HOME/.dvm/scripts/dvm" ] ; then
    . "$HOME/.dvm/scripts/dvm" ;
    dvm use 2.063.2
fi

if [ "$1" = "lib" ] ; then
	shift
	rdmd -m32 --build-only -debug -gc -oflib/dstep.o -Idstack/mambo -Idstack -c "$@" dstep/translator/CApi.d
	dmd -lib lib/dstep.o -oflib/libdstep.a
else
	rdmd -m32 --build-only -v -debug -gc -ofbin/dstep -Idstack/mambo -Idstack -L-L. -L-lclang -L-ltango -L-rpath -L. "$@" dstep/driver/DStep.d
fi