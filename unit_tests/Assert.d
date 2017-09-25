/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 30, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import core.exception;

import clang.c.Index;
import clang.Type;
import clang.Util;

import Common;

import dstep.translator.CommentIndex;
import dstep.translator.Context;
import dstep.translator.IncludeHandler;
import dstep.translator.MacroDefinition;
import dstep.translator.MacroDefinitionParser;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.Type;

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

    auto children = translUnit.cursor.children(true);

    if (children.length != 1)
        throw new AssertError("Assertion failure", file, line);

    Cursor cursor = children[0];

    assert(cursor.kind == CXCursorKind.macroDefinition);

    auto tokens = cursor.tokens;

    auto definition = parsePartialMacroDefinition(tokens, context.typeNames);

    Set!string imports;
    Set!string params;

    string actual = null;

    if (definition !is null)
    {
        if (definition.expr !is null)
            actual = definition.expr.debraced.translate(context, params, imports);
    }

    assertEq(expected, actual, false, file, line);
}

void assertDoesntParseMacroExpression(
    string source,
    string file = __FILE__,
    size_t line = __LINE__)
{
    auto translUnit = makeTranslationUnit(source);

    Options options;
    Output output = new Output;

    Context context = new Context(translUnit, options);

    auto children = translUnit.cursor.children(true);

    if (children.length != 1)
        throw new AssertError("Assertion failure", file, line);

    Cursor cursor = children[0];

    assert(cursor.kind == CXCursorKind.macroDefinition);

    auto tokens = cursor.tokens;

    auto definition = parsePartialMacroDefinition(tokens, context.typeNames);

    if (definition !is null)
        throw new AssertError("Assertion failure", file, line);
}

Type parseTypeName(string source)
{
    Cursor[string] table;
    auto tokens = tokenize(source);
    return dstep.translator.MacroDefinitionParser.parseTypeName(tokens, table);
}

void assertParsedTypeHasKind(
    string source,
    CXTypeKind kind,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import core.exception;

    Type type = parseTypeName(source);

    if (type.kind != kind)
        throw new AssertError("Assertion failure", file, line);
}

void assertTypeIsntParsed(
    string source,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import core.exception;

    Type type = parseTypeName(source);

    if (type.isValid)
        throw new AssertError("Assertion failure", file, line);
}
