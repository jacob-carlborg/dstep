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
#include <stdint.h>

#define __le64 uint64_t
C",
    q"D
extern (C):

alias __le64 = ulong;
D");

}

