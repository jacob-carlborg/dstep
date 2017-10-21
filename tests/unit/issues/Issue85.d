/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Aug 09, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

// Fix 85: dstep not converting `const T x[]` to `const (T)* x`.
unittest
{
    assertTranslates(q"C
#include <stddef.h>

int complex_forward (const double data[], const size_t stride, const size_t n, double result[]);
C",
q"D
extern (C):

int complex_forward (const(double)* data, const size_t stride, const size_t n, double* result);
D");

}

