/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 30, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import core.exception;

import clang.c.Index;

import Common;

import dstep.translator.CommentIndex;
import dstep.translator.Context;
import dstep.translator.IncludeHandler;
import dstep.translator.MacroDefinition;
import dstep.translator.Output;
import dstep.translator.Translator;

void assertTranslatesMacroDefinition(
    string source,
    string expected,
    string file = __FILE__,
    size_t line = __LINE__)
{
    auto translUnit = makeTranslationUnit(source);

    Options options;
    Output output = new Output;

    Context context = new Context(translUnit, options);

    context.macroLinkage = "";

    auto children = translUnit.cursor.children(true);

    if (children.length != 1)
        throw new AssertError("Assertion failure", file, line);

    translateMacroDefinition(output, context, children[0]);

    assertEq(expected, output.data, false, file, line);
}

void assertTranslatesMacroExpression(
    string source,
    string expected,
    string file = __FILE__,
    size_t line = __LINE__)
{
    auto translUnit = makeTranslationUnit(source);

    Options options;
    Output output = new Output;

    Context context = new Context(translUnit, options);

    context.macroLinkage = "";

    auto children = translUnit.cursor.children(true);

    if (children.length != 1)
        throw new AssertError("Assertion failure", file, line);

    Cursor cursor = children[0];

    assert(cursor.kind == CXCursorKind.CXCursor_MacroDefinition);

    auto definition = parsePartialMacroDefinition(cursor.tokens, context.typeNames);

    bool[string] imports;
    string actual = null;

    if (definition !is null)
    {
        if (definition.expr !is null)
            actual = definition.expr.debraced.translate(imports);
    }

    assertEq(expected, actual, false, file, line);
}