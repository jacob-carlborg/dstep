/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: October 07, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import Common;

import clang.c.Index;
import clang.Compiler;
import clang.Index;
import clang.TranslationUnit;
import clang.Util;

import dstep.translator.HeaderIndex;

// Include standard library module when the dependency is used in macro.
unittest
{
    assertTranslates(
q"C
#include <stdlib.h>

#define FOO RAND_MAX
C",
q"D
import core.stdc.stdlib;

extern (C):

enum FOO = RAND_MAX;
D");

    assertTranslates(
q"C
#include <limits.h>

#define FOO INT_MAX
C",
q"D
import core.stdc.limits;

extern (C):

enum FOO = INT_MAX;
D");

assertTranslates(
q"C
#include <stdint.h>

#define FOO UINT32_MAX
C",
q"D
import core.stdc.stdint;

extern (C):

enum FOO = UINT32_MAX;
D");

}

version(Posix)
{

unittest
{
    // TODO: Following requires an improvement as the definition of _IOR in
    // core.sys.posix.sys.ioctl has different interface
    // (it takes two arguments).
    assertTranslates(q"C
#include <sys/ioctl.h>

#define FOO _IOR('o', 61, int)
C",
q"D
import core.sys.posix.sys.ioctl;

extern (C):

enum FOO = _IOR!int('o', 61);
D");

}

}
