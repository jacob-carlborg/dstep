/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jan 21, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

// Fix 114: Crash on recursive typedef.
unittest
{
    assertTranslates(q"C
typedef struct _Foo_List {
    void *data;
    struct _Foo_List *next;
} Foo_List;
C",
q"D
extern (C):

struct _Foo_List
{
    void* data;
    _Foo_List* next;
}

alias _Foo_List Foo_List;
D");

}
