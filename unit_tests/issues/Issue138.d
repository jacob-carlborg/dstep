/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: June 04, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;
import dstep.translator.Options;

// Fix 138: Repeated declarations cause problems.
unittest
{
    assertTranslates(q"C
extern const unsigned fe_bandwidth_name[8];
extern const unsigned fe_bandwidth_name[8];
C",
q"D
extern (C):

extern __gshared const(uint)[8] fe_bandwidth_name;
D");

}
