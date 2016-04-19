# DStep Change Log

## Unreleased
### New/Changed Features

* Support for simple defines (like `#define FOO 1`)
* Support for translation of preprocessor constants in array sizes.
* Basic unit tests were added
* Most of cucumber tests was replaced with D-based tests.
* Statements are translated in original 'C' order now.
* Multiple input files can be processed in different threads.

## Version 0.2.1
### New/Changed Features

* Clang internal header files are now included in the executable
* A script for testing multiple versions of libclang has been added
* DStep outputs spaces instead of tabs for indentation
* Update Clang bindings to 3.7.0
* Run tests on Travis-CI

#### Objective-C

* Selectors are translated to `@selector("foo")`
* `id` is translated to `ObjcObject`

### Bugs Fixed

* Issue #42: Compile failure with DMD v2.0.68
* Issue #37: Regression: clang 3.5 causes struct members to be defined again
* Issue #26: dstep dumps core on a simple header

## Version 0.1.1
### New/Changed Features

* DStep can now be compiled with DMD 2.066.1

### Bugs Fixed

* Fix paths in the tests on OS X Yosemite

## Version 0.1.0
### New/Changed Features

* Add support for compiling as 64bit
* Removed printing of output to stdout
* Add support for and FreeBSD (32 and 64bit)
* Infer the output filename of the input filename
* Make arguments more consistent

#### Objective-C

* Support for properties
* Support for protocols
* Support for categories

### Bugs Fixed

* Issue 1: Escape D keywords for function parameters
* Issue 5: Forward declaration of structures
* Issue 4: Handle typedefs of empty struct

## Version 0.0.1
### New/Changed Features

* Initial release
