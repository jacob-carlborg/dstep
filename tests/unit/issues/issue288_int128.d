/**
 * Copyright: Copyright (c) 2023 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: November 10, 2023
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;
import dstep.translator.Options;

unittest
{
    assertTranslates(
q"C
__int128 a();
unsigned __int128 b();
__int128_t c();
__uint128_t d();
typedef __uint128_t tb_uint128_t;
C",

q"D
import core.int128;

extern (C):

Cent a ();
Cent b ();
Cent c ();
Cent d ();
alias tb_uint128_t = Cent;
D", Options(reduceAliases: true));
}
