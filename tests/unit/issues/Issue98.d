/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Oct 23, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

// Fix 98: dstep segfaults: Unhandled type kind cast(CXTypeKind)119.
unittest
{
    assertTranslates(q"C
struct timeval { };

void term_await_started(const struct timeval *timeout);
C",
q"D
extern (C):

struct timeval
{
}

void term_await_started (const(timeval)* timeout);
D");

}

