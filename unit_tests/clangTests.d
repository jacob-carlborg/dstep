/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import std.stdio;

import clang.Visitor;
import clang.Util;

import Common;

// Empty source should yield empty cursor.
unittest
{
    auto unit = makeTranslationUnit("");
    assert(unit.cursor.children(true).length == 0);
}

// `tokens` should yield tokens.
unittest
{
    auto unit = makeTranslationUnit("#define true false\n");
    auto tokens = unit.cursor().children(true)[0].tokens;

    assert(tokens[0].spelling == "true");
    assert(tokens[1].spelling == "false");
}

// `tokens` should yield tokens.
unittest
{
    auto unit = makeTranslationUnit("#define FOO 0\n#define BAR 1");
    auto cursor = unit.cursor().children(true)[0];
    auto tokens = cursor.tokens;

    assert(tokens.length == 2);
    assert(tokens[0].spelling == "FOO");
    assert(tokens[1].spelling == "0");
}
