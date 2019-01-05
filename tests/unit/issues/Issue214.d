/**
 * Copyright: Copyright (c) 2018 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: January 04, 2019
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

unittest
{
    assertTranslates(
    q"C
#define bar float
#define FOO(a) (bar)(a)
C",
    q"D
extern (C):

alias bar = float;

extern (D) auto FOO(T)(auto ref T a)
{
    return cast(bar) a;
}
D");

}
