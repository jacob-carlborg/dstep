/**
 * Copyright: Copyright (c) 2018 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: September 29, 2018
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

unittest
{
    assertTranslates(
    q"C
#include <limits.h>

typedef enum _ValueBinding {
    ValueBindingWeak,
    ValueBindingEnd = INT_MAX
} ValueBinding;
C",
    q"D
import core.stdc.limits;

extern (C):

enum _ValueBinding
{
    ValueBindingWeak = 0,
    ValueBindingEnd = INT_MAX
}

alias ValueBinding = _ValueBinding;
D");

    version (linux) {
        assertTranslates(
    q"C
#include <sys/stat.h>

void* DirCacheLoadFile (const char *cache_file, struct stat *file_stat);
C",
    q"D
import core.sys.posix.sys.stat;

extern (C):

void* DirCacheLoadFile (const(char)* cache_file, stat_t* file_stat);
D");
    }
}
