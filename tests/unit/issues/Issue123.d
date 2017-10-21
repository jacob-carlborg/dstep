/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: September 23, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;
import dstep.translator.Translator;

// Test standard enum.
unittest
{
	assertTranslates(
q"C
#include <limits.h>

#define TEST INT_MAX

C",
q"D
import core.stdc.limits;

extern (C):

enum TEST = INT_MAX;

D");

}
