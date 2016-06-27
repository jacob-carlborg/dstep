# DStep Change Log

## Unreleased
### New/Changed Features

* Support for simple defines (like `#define FOO 1`).
* Translation of defines to functions (like `#define FOO(a, b) a + b`).
* Support for translation of whole packages (--package CLI option).
* Support for translation of preprocessor constants in array sizes.
* Support for global comments and comments inside structs and enums.
* Support for removing excessive newlines and keeping original spacing.
* Basic unit tests were added.
* Most of cucumber tests was replaced with D-based tests.
* Statements are translated in original 'C' order now.
* Multiple input files can be processed in different threads.
* Extend a functionality that automatically replaces aliases to basic types with their D equivalents.
* Add a switch `dont-reduce-aliases` which disables the above functionality.

### Bugs fixed
Issue #2: Self alias should be removed bug.
Issue #10: Embedded struct not generated.
Issue #29: Don't name anonymous enums.
Issue #39: Recognize and translate __attribute__((__packed__)).
Issue #46: Generating code that will not compile.
Issue #47: Treatment of #define enhancement.
Issue #50: struct typedef generates recursive alias bug.

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
