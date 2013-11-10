# DStep

DStep is a tool for translating C and Objective-C headers to D modules.

## Download

Pre-compiled binaries are available for Mac OS X, Linux and FreeBSD. As 32 and 64bit. See the
[releases](https://github.com/jacob-carlborg/dstep/releases) section.

## License

The source code is available under the [Boost Software License 1.0](http://www.boost.org/LICENSE_1_0.txt)

## Building

### Requirements

* libclang - [http://clang.llvm.org](http://clang.llvm.org) - 3.1 or later
* DMD - [http://dlang.org/download.html](http://dlang.org/download.html) - 2.063.2 - 2.064.2
* Tango - [https://github.com/SiegeLord/Tango-D2](https://github.com/SiegeLord/Tango-D2)

### Building

1. Install all requirements, see [below](#requirements-1)
2. Clone the repository by running:

		$ git clone --recursive git://github.com/jacob-carlborg/dstep.git

3. run `./build.sh`

## Usage

	$ dstep Foo.h -o Foo.d

For translating Objective-C headers add the `-ObjC` flag.

	$ dstep Foo.h -o Foo.d -ObjC

Use `-h` for usage information. Any flags recognized by Clang can be used.

## Requirements

### libclang

This tool requires libclang. Any version that is 3.1 or later and binary compatible with 3.1
should work. Either download the pre-compatible libraries from the LLVM site or use libclang
shipping with your system or available from the system package manager.

Some header files will require "stdarg.h" and/or "stddef.h". These are so called builtin
includes and are shipped with Clang. They need to be placed in the standard header locations
or explicitly referenced with the `-I` flag. For more information see the
[Clang FAQ](http://clang.llvm.org/docs/FAQ.html#i-get-errors-about-some-headers-being-missing-stddef-h-stdarg-h).

Download the pre-compiled libraries here:

[http://llvm.org/releases/download.html#3.1](http://llvm.org/releases/download.html#3.1)

Alternatively compile libclang yourself:

	$ git clone http://llvm.org/git/llvm.git
	$ cd llvm
	$ git checkout release_31
	$ cd tools
	$ git clone http://llvm.org/git/clang.git
	$ cd clang
	$ git checkout release_31
	$ cd ../..
	$ ./configure --enable-optimized
	$ cp Release+Asserts/lib/libclang.<dylib|so> <path/to/dstep>

### Tango

	$ git clone https://github.com/SiegeLord/Tango-D2
	$ cd Tango-D2
	$ ./build/script/bob.rb -r dmd -c dmd .
	$ cp libtango.a <path/to/dstep>