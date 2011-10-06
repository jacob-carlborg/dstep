#!/bin/sh

dvm use 2.055
rdmd -L-L. -L-lclang -L-rpath -L. dstep/driver/DStep.d