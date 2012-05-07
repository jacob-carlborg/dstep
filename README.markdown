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
2. Clone the repository by running:

		git clone --recursive git://github.com/jacob-carlborg/dstep.git

3. run `./build.sh`

## Usage

	dstep Foo.h -o Foo.d

For translating Objective-C headers add the `-ObjC` flag.

	dstep Foo.h -o Foo.d -ObjC

Any flags recognized by Clang can be used.