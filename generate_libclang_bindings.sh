#/bin/bash

set -e

if [ $# -eq 0 ]; then
  echo 'Please specify the path to the libclang C header files'
  echo 'Example: ./generate_libclang_bindings.sh /opt/local/libexec/llvm-3.8/include'

  exit 1
fi

cwd=$(pwd)
pushd "$1"/clang-c > /dev/null
"$cwd"/bin/dstep ./*.h \
  -I"$cwd/$1" \
  -Iresources \
  --public-submodules \
  --package clang.c \
  --space-after-function-name=false \
  -o "$cwd"/clang/c \
  --skip CXCursorVisitorBlock \
  --skip CXCursorAndRangeVisitorBlock \
  --skip clang_visitChildrenWithBlock \
  --skip clang_findReferencesInFileWithBlock \
  --skip clang_findIncludesInFileWithBlock \
  --rename-enum-members

popd > /dev/null
