/**
 * Copyright: Copyright (c) 2023 Jacob Carlborg. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: July 28, 2023
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

unittest
{
    assertTranslates(
    q"C
enum
{
  Foo
};

#define Bar Foo
C",

    q"D
extern (C):

enum
{
    Foo = 0
}

enum Bar = Foo;
D");
}
