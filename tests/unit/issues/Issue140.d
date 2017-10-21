/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: June 04, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;
import dstep.translator.Options;

// Fix 140: On enums and scope
unittest
{
    Options options;
    options.aliasEnumMembers = true;

    assertTranslates(q"C
typedef enum fe_delivery_system {
    SYS_UNDEFINED,
    SYS_DVBC_ANNEX_A,
} fe_delivery_system_t;
C",
q"D
extern (C):

enum fe_delivery_system
{
    SYS_UNDEFINED = 0,
    SYS_DVBC_ANNEX_A = 1
}

alias SYS_UNDEFINED = fe_delivery_system.SYS_UNDEFINED;
alias SYS_DVBC_ANNEX_A = fe_delivery_system.SYS_DVBC_ANNEX_A;

alias fe_delivery_system_t = fe_delivery_system;
D",
    options);

}
