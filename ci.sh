#!/usr/bin/env bash

set -exo pipefail

download() {
  curl --retry 3 -fsS "$1"
}

d_compiler() {
  echo "$DSTEP_COMPILER" | \
    sed 's/-latest//' | \
    sed 's/dmd-master/dmd-nightly/'
}

install_d_compiler() {
  download https://dlang.org/d-keyring.gpg | gpg --import /dev/stdin
  source $(download https://dlang.org/install.sh | bash -s "$(d_compiler)" -a)
}

run() {
  ./configure --llvm-path "llvm-$DSTEP_LLVM_VERSION" --statically-link-clang
  dub test --verror
}

install_d_compiler
run
