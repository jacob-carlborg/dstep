## Introduction

DStep is a tool for translating C and Objective-C headers to D modules.

## Building

### Requirements

* Clang - http://clang.llvm.org - 3.1
* DVM - https://bitbucket.org/doob/dvm
* DMD 2.060 - install using DVM
* Tango - https://github.com/SiegeLord/Tango-D2

### Building

1. Install all requirements, see below (currently only 32bit is supported due to a bug in DMD)
2. Clone the repository by running:

		$ git clone --recursive git://github.com/jacob-carlborg/dstep.git

3. run `./build.sh`

## Usage

	$ dstep Foo.h -o Foo.d

For translating Objective-C headers add the `-ObjC` flag.

	$ dstep Foo.h -o Foo.d -ObjC

Any flags recognized by Clang can be used.

## Install Requirements

These are install instructions for Mac OS X 10.7 and later. It should be easy to modify to work on other
Posix platforms.

### LLVM and Clang

	$ git clone http://llvm.org/git/llvm.git
	$ cd llvm
	$ git co -b release_31
	$ cd tools
	$ git clone http://llvm.org/git/clang.git
	$ cd clang
	$ git co -b release_31
	$ cd ../..
	$ ./configure --build=i686-apple-darwin11 --enable-optimized
	$ cp Release+Asserts/lib/libclang.dylib <path/to/dstep>

### DVM

	$ wget -O dvm https://bitbucket.org/doob/dvm/downloads/dvm-0.4.0-osx
	$ chmod +x dvm
	$ ./dvm install dvm

### DMD

	$ dvm install 2.060
	$ dvm use 2.060

### Tango

	$ git clone https://github.com/SiegeLord/Tango-D2
	$ cd Tango-D2
	$ ./build/script/bob.rb -r dmd -c dmd .
	$ cp libtango.a <path/to/dstep>