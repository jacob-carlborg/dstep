# DStep Change Log

## Unreleased
### New/Changed Features

* Support for simple defines (like `#define FOO 1`)
* Translation of defines to functions (like `#define FOO(a, b) a + b`)
* Support for preprocessor token-pasting operator (##)
* Support for translation of whole packages (`--package` CLI option)
* Support for translation of preprocessor constants in array sizes
* Support for global comments and comments inside structs and enums
* Detecting collisions of renamed tag-space names (struct name_t ...) with existing ones
* Special treatment of a comment before header guard
* Support for removing excessive newlines and keeping original spacing
* Basic unit tests were added
* Cucumber tests were replaced with D-based tests
* Statements are now translated in the original order as the input file
* Multiple input files can be processed at once
* Extend a functionality that automatically replaces aliases to basic types with their D equivalents
* Add a switch `--dont-reduce-aliases` which disables the above functionality
* Add a switch `--alias-enum-members` which enables generation of aliases for enum members in the global scope
* Add the `libclang` bindings as a test case
* Add support for Microsoft Windows
* Run Windows tests on AppVeyor
* Handle complex floating-point types.
* Use the new alias syntax (`alias Y = X`) in the output
* Support for custom global attributes (e.g. `nothrow`, `@nogc`)
* Add support for building with LDC

### Bugs Fixed

* [Issue 2](https://github.com/jacob-carlborg/dstep/issues/2): Self alias should be removed bug
* [Issue 8](https://github.com/jacob-carlborg/dstep/issues/8): Typedef and anonymous structs
* [Issue 10](https://github.com/jacob-carlborg/dstep/issues/10): Embedded struct not generated
* [Issue 20](https://github.com/jacob-carlborg/dstep/issues/20): `#define` (simplest cases only?)
* [Issue 21](https://github.com/jacob-carlborg/dstep/issues/21): `wchar_t` should be translated to `core.stdc.stddef.wchar_t`
* [Issue 28](https://github.com/jacob-carlborg/dstep/issues/28): Crashes if fed nonexistent header
* [Issue 29](https://github.com/jacob-carlborg/dstep/issues/29): Don't name anonymous enums
* [Issue 30](https://github.com/jacob-carlborg/dstep/issues/30): Single space inserted after function names
* [Issue 38](https://github.com/jacob-carlborg/dstep/issues/38): Spurious generation of variadic args rather than implicit void
* [Issue 39](https://github.com/jacob-carlborg/dstep/issues/39): Recognize and translate `__attribute__((__packed__))`
* [Issue 46](https://github.com/jacob-carlborg/dstep/issues/46): Generating code that will not compile
* [Issue 47](https://github.com/jacob-carlborg/dstep/issues/47): Treatment of #define enhancement
* [Issue 50](https://github.com/jacob-carlborg/dstep/issues/50): struct typedef generates recursive alias bug
* [Issue 59](https://github.com/jacob-carlborg/dstep/issues/59): Shouldn't dstep exit with status code when there is some kind of error
* [Issue 83](https://github.com/jacob-carlborg/dstep/issues/83): New multiline translation
* [Issue 85](https://github.com/jacob-carlborg/dstep/issues/85): dstep not converting `const T x[]` to `const (T)* x`
* [Issue 107](https://github.com/jacob-carlborg/dstep/issues/107): Handle typedef of opaque structs.
* [Issue 114](https://github.com/jacob-carlborg/dstep/issues/114): Crash on recursive typedef.
* [Issue 116](https://github.com/jacob-carlborg/dstep/issues/116): Option --space-after-function-name doesn't work with function pointer syntax.
* [Issue 117](https://github.com/jacob-carlborg/dstep/issues/117): fatal error: 'limits.h' file not found.
* [Issue 137](https://github.com/jacob-carlborg/dstep/issues/137): struct member expansion.
* [Issue 138](https://github.com/jacob-carlborg/dstep/issues/138): Repeated declarations cause problems.
* [Issue 140](https://github.com/jacob-carlborg/dstep/issues/140): On enums and scope.

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

* [Issue 42](https://github.com/jacob-carlborg/dstep/issues/42): Compile failure with DMD v2.0.68
* [Issue 37](https://github.com/jacob-carlborg/dstep/issues/37): Regression: clang 3.5 causes struct members to be defined again
* [Issue 26](https://github.com/jacob-carlborg/dstep/issues/26): dstep dumps core on a simple header

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

* [Issue 1](https://github.com/jacob-carlborg/dstep/issues/1): Escape D keywords for function parameters
* [Issue 5](https://github.com/jacob-carlborg/dstep/issues/5): Forward declaration of structures
* [Issue 4](https://github.com/jacob-carlborg/dstep/issues/4): Handle typedefs of empty struct

## Version 0.0.1
### New/Changed Features

* Initial release
