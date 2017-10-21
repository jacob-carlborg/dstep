/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jul 29, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import dstep.translator.Options;

import Common;

unittest
{
    assertTranslates(q"C
void foo();
void bar(const char* fmt, ...);
void baz(void);
C",
q"D
extern (C):

void foo ();
void bar (const(char)* fmt, ...);
void baz ();
D");

    Options options;
    options.zeroParamIsVararg = true;

    assertTranslates(q"C
void foo();
void bar(const char* fmt, ...);
void baz(void);
C",
q"D
extern (C):

void foo (...);
void bar (const(char)* fmt, ...);
void baz ();
D", options);

}
