# DStep

DStep is a tool for translating C and Objective-C headers to D modules.

## Download

For the latest release see: [releases/latest](https://github.com/jacob-carlborg/dstep/releases/latest).

Pre-compiled binaries are available for OS X, Linux and FreeBSD, as 64bit. See the
[releases](https://github.com/jacob-carlborg/dstep/releases) section.

Arch packages are available in [community] repository (thanks to Михаил Страшун):

[https://www.archlinux.org/packages/?q=dstep](https://www.archlinux.org/packages/?q=dstep)

Alternatively install via [Dub](http://code.dlang.org/download)

## License

The source code is available under the [Boost Software License 1.0](http://www.boost.org/LICENSE_1_0.txt)

## Building

### Requirements

* libclang - [http://clang.llvm.org](http://clang.llvm.org) - 3.4 or later that is binary compatible with 3.4
* DMD - [http://dlang.org/download.html](http://dlang.org/download.html) - 2.069.2
* Dub [http://code.dlang.org/download](http://code.dlang.org/download)

### Building

1. Install all requirements, see [above](#requirements)
2. Clone the repository by running:

        $ git clone git://github.com/jacob-carlborg/dstep.git

3. run `dub build`

## Usage

    $ dstep Foo.h -o Foo.d

For translating Objective-C headers add the `-ObjC` flag.

    $ dstep Foo.h -o Foo.d -ObjC

For translating multiple files at once, simply pass all the files to dstep.
In this case though, `-o` (if given) would point to output directory name.
The directory will be created if it doesn't exist.

    $ dstep Foo1.h Foo2.h Foo3.h .... FooN.h -o ./outputDirectory/

Use `-h` for usage information. Any flags recognized by Clang can be used.

## Limitations/Known issues

* Doesn't translate preprocessor macros, with exception to simple constants and functions.
* Doesn't translate `#include` to `import`. A few standard C headers are translated
* Doesn't translate C++ at all
* Umbrella headers. Some headers just serve to include other headers. If these other headers contain some form of protection, like `#error`, to be included directly this can cause problems for DStep
* Some headers are designed to always be included together with other header files. These headers may very well use symbols from other header files without including them itself. Since DStep is designed to convert header files one-by-one this doesn't work. There are two workarounds for this:

    1. Add `#include`-directives for the header files the header file is actually using
    2. Use the `-include <file>` flag available in Clang to indicate the given `<file>` should be processed before the file that should be translated. DStep accepts all flags Clang accepts
