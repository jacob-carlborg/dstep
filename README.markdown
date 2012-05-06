## Introduction

DStep is a tool for translating C and Objective-C headers to D modules.

## Building

### Requirements

* Clang - http://clang.llvm.org
* DVM - https://bitbucket.org/doob/dvm
* DMD 2.059 - install using DVM
* Tango - https://github.com/SiegeLord/Tango-D2

### Building

1. Install all requirements
2. Clone the repository
3. Pull down the submodules by running:

		git submodule init
		git submodule update
		cd dstack
		git submodule init
		git submodule update

4. run `./build.sh`

## Usage

	dstep Foo.h -o Foo.d

For translating Objective-C headers add the `-ObjC` flag.

	dstep Foo.h -o Foo.d -ObjC

Any flags recognized by Clang can be used.