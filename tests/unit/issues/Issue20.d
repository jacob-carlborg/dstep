/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Aug 10, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

// Fix 20: #define (simplest cases only?).
unittest
{
    assertTranslates(q"C
#define X (1)
#define Y ((float)-X)
#define f(x, b) ((a) + (b))
#define foo 1
C",
q"D
extern (C):

enum X = 1;
enum Y = cast(float) -X;

extern (D) auto f(T0, T1)(auto ref T0 x, auto ref T1 b)
{
    return a + b;
}

enum foo = 1;
D");

}
