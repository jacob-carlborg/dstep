#!/bin/sh

dvm use 2.057
rdmd -L-L. -L-lclang -L-rpath -L. dstep/driver/DStep.d