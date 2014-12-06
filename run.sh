#!/bin/sh

./build.sh

if [ "$?" = 0 ] ; then
    osx_sdk_path="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.10.sdk"
    osx_internal_include_path="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/lib/clang/6.0/include"
  ./bin/dstep foo.h -o foo.d -ObjC -isysroot $osx_sdk_path -I$osx_internal_include_path
fi
