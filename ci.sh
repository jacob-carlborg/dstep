#!/usr/bin/env bash

# Environment variables:
# DSTEP_COMPILER: the compiler to build with
# DSTEP_LLVM_VERSION: the version of LLVM to link with
# DSTEP_TARGET_TRIPLE: the target triple to build for
# DSTEP_RELEASE_PLATFORM: the name of the platform

set -exo pipefail

export MACOSX_DEPLOYMENT_TARGET=10.9

download() {
  curl --retry 3 -fsS "$@"
}

d_compiler() {
  echo "$DSTEP_COMPILER" | \
    sed 's/-latest//' | \
    sed 's/dmd-master/dmd-nightly/'
}

install_d_compiler() {
  if [ "$DSTEP_TARGET_TRIPLE" = 'i386-pc-windows-msvc' ]; then
    local target_dir="~/dlang/ldc-$(d_compiler)"
    mkdir -p "$target_dir"
    download -o ldc2.7z "https://github.com/ldc-developers/ldc/releases/download/v$(d_compiler)/ldc2-$(d_compiler)-windows-multilib.7z"
    7z x ldc2.7z -o"$target_dir" -r '-x!*/'
    rm ldc2.7z
    export PATH="$target_dir/bin:$PATH"
  else
    download https://dlang.org/d-keyring.gpg | gpg --import /dev/stdin
    source $(download https://dlang.org/install.sh | bash -s "$(d_compiler)" -a)
  fi
}

configure() {
  ./configure --llvm-path "llvm-$DSTEP_LLVM_VERSION" --statically-link-clang
}

target_triple_arg() {
  if echo "$(d_compiler)" | grep -i -q ldc; then
    echo "--mtriple=$DSTEP_TARGET_TRIPLE"
  else
    echo "-target=$DSTEP_TARGET_TRIPLE"
  fi
}

run_tests() {
  DFLAGS="$(target_triple_arg)" dub test --verror
}

release() {
  DFLAGS="$(target_triple_arg)" dub build -b release --verror
  strip "$target_path"*
  archive
}

version() {
  "$target_path"* --version
}

release_name() {
  echo "$app_name-$(version)-$DSTEP_RELEASE_PLATFORM"
}

archive() {
  if uname | grep -i -q mingw; then
    7z a "$(release_name).7z" "$target_path"*
  else
    tar Jcf "$(release_name).tar.xz" -C "$target_dir" "$app_name"
  fi
}

app_name="dstep"
target_dir="bin"
target_path="$target_dir/$app_name"

install_d_compiler
configure

case "$1" in
  'test') run_tests ;;
  'release') release ;;
esac
