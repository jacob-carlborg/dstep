#!/usr/bin/env bash

# Environment variables:
# DSTEP_COMPILER: the compiler to build with
# DSTEP_LLVM_VERSION: the version of LLVM to link with
# DSTEP_TARGET_TRIPLE: the target triple to build for
# DSTEP_RELEASE_PLATFORM: the name of the platform

set -exo pipefail

export MACOSX_DEPLOYMENT_TARGET=10.9

download() {
  curl --retry 3 -fsSL "$1"
}

d_compiler() {
  echo "$DSTEP_COMPILER" | \
    sed 's/-latest//' | \
    sed 's/dmd-master/dmd-nightly/'
}

# dub selects the compiler via the `DC` environment variable, recognizing it by
# the executable's base name. Resolve `DC` to an absolute path so dub always
# finds the compiler directly instead of searching `PATH`. Some compiler
# packages (e.g. certain DMD betas on Windows) ship without a bundled dub, in
# which case install.sh installs a standalone dub that otherwise fails to locate
# the compiler by name on `PATH`.
pin_compiler_path() {
  local path
  path="$(command -v "$DC")" || return 0

  if command -v cygpath > /dev/null 2>&1; then
    path="$(cygpath -w "$path")"
  fi

  export DC="$path"
}

# dlang.org/install.sh only provides glibc builds, which cannot run on musl
# based distributions such as Alpine Linux.
on_musl() {
  [ -f /etc/alpine-release ]
}

ldc_release_channel() {
  case "$DSTEP_COMPILER" in
    ldc-beta) echo LATEST_BETA ;;
    *) echo LATEST ;;
  esac
}

# Install the official musl build of LDC directly, since install.sh cannot.
install_ldc_musl() {
  local version arch dir
  version="$(download "https://ldc-developers.github.io/$(ldc_release_channel)")"
  arch="$(uname -m)"
  dir="ldc2-$version-alpine-$arch"

  download "https://github.com/ldc-developers/ldc/releases/download/v$version/$dir.tar.xz" | \
    tar xJ

  export PATH="$PWD/$dir/bin:$PATH"
  export DC=ldc2
  export DMD=ldmd2
}

install_d_compiler() {
  if on_musl; then
    install_ldc_musl
  else
    download https://dlang.org/d-keyring.gpg | gpg --import /dev/stdin
    source $(download https://dlang.org/install.sh | bash -s "$(d_compiler)" -a)
  fi

  pin_compiler_path
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
