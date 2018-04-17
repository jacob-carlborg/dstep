/**
 * Copyright: Copyright (c) 2018 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: April 17, 2018
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

unittest
{
    assertTranslates(
    q"C
    /*  Yada, yada, yada,
            foo(a + b) = foo(a) * bar(b) + bar(a) * foo(b)
            bar(a + b) = bar(a) * bar(b) - foo(a) * foo(b)

        Yada, yada,
        yada, yada.

        Yada, yada,
        yada, yada.
    */
C",
    q"D
/*  Yada, yada, yada,
        foo(a + b) = foo(a) * bar(b) + bar(a) * foo(b)
        bar(a + b) = bar(a) * bar(b) - foo(a) * foo(b)

    Yada, yada,
    yada, yada.

    Yada, yada,
    yada, yada.
*/
D");

}

