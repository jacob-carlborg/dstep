/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: May 20, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import std.stdio;
import Common;
import dstep.translator.CommentIndex;

unittest
{
    string test = q"C

/* This is comment. */

/* This is another comment. */

#define FOO 64
#define BAR 128

/* As most comments this comment is obsolete.
   BAZ is 255. */

#define BAZ 256

struct Foo {
    int a;
    int b;
};

/* Another lengthy comment.
Foo bar baz.
Foo bar baz.
Foo bar baz.
Foo bar baz.
Foo bar baz.

*/

    /* */

C";

    auto translUnit = makeTranslationUnit(test);

    auto commentIndex = new CommentIndex(translUnit);

    auto full = commentIndex.queryComments(0, cast(uint) test.length);

    assert(full.length == 5);

    auto alpha = commentIndex.queryComments(1, 55);

    assert(alpha.length == 2);
    assert(alpha[0].content == "/* This is comment. */");
    assert(alpha[1].content == "/* This is another comment. */");
}
