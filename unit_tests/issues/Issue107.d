/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jan 15, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

// Fix 107: Handle typedef of opaque structs.
unittest
{
    assertTranslates(q"C
typedef struct foo foo;
C",
q"D
extern (C):

struct foo;
D");

}
