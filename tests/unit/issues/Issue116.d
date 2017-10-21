/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jan 26, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;
import dstep.translator.Options;

// Fix 116: Option --space-after-function-name doesn't work with function
// pointer syntax.
unittest
{
    Options options;
    options.spaceAfterFunctionName = false;

    assertTranslates(
q"C
int foo(void);

typedef int (*Fun0)(void);
typedef int (*Fun1)(int (*param)(void));

struct Foo {
  int (*bar)(void);
};
C",
q"D
extern (C):

int foo();

alias Fun0 = int function();
alias Fun1 = int function(int function() param);

struct Foo
{
    int function() bar;
}
D", options);

}
