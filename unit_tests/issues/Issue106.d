/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jan 15, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

// Fix 106: Handle complex floating-point types.
unittest
{
    assertTranslates(
q"C
float _Complex foo;
double _Complex bar;
long double _Complex baz;
C",
q"D
extern (C):

extern __gshared cfloat foo;
extern __gshared cdouble bar;
extern __gshared creal baz;
D");

}
