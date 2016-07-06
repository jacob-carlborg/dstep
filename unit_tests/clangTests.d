/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import std.stdio;

import clang.c.Index;

import clang.Cursor;
import clang.Util;
import clang.Visitor;

import Common;

// Empty source should yield empty cursor.
unittest
{
    auto translUnit = makeTranslationUnit("");
    assert(translUnit.cursor.children(true).length == 0);
}

// `tokens` should yield tokens.
unittest
{
    auto translUnit = makeTranslationUnit("#define true false\n");
    auto tokens = translUnit.cursor().children(true)[0].tokens;

    assert(tokens[0].spelling == "true");
    assert(tokens[1].spelling == "false");
}

// `tokens` should yield tokens.
unittest
{
    auto translUnit = makeTranslationUnit("#define FOO 0\n#define BAR 1");
    auto cursor = translUnit.cursor().children(true)[0];
    auto tokens = cursor.tokens;

    assert(tokens.length == 2);
    assert(tokens[0].spelling == "FOO");
    assert(tokens[1].spelling == "0");
}

// Test TranslationUnit.includeLocations.
unittest
{
    auto index = Index(false, false);

    auto translUnit = TranslationUnit.parse(
        index,
        "test_files/include/file.h",
        []);

    auto locations = translUnit.includeLocations;

    assert(locations.length == 10);
    assert(locations[0].path == "");
    assert(locations[1].path == "test_files/include/file.h");
    assert(locations[2].path == "test_files/include/subfile1.h");
    assert(locations[3].path == "test_files/include/file.h");
    assert(locations[4].path == "test_files/include/subfile2.h");
    assert(locations[5].path == "test_files/include/subsubfile1.h");
    assert(locations[6].path == "test_files/include/subfile2.h");
    assert(locations[7].path == "test_files/include/file.h");
    assert(locations[8].path == "test_files/include/subfile3.h");
    assert(locations[9].path == "test_files/include/file.h");

    assert(locations[7].offset == 50);
}

// Test TranslationUnit.includeLocations - a case without includes.
unittest
{
    auto index = Index(false, false);

    auto translUnit = TranslationUnit.parse(
        index,
        "test_files/include/subfile1.h",
        []);

    auto locations = translUnit.includeLocations;

    assert(locations.length == 2);
    assert(locations[0].path == "");
    assert(locations[1].path == "test_files/include/subfile1.h");
}

// Test TranslationUnit.relativeLocationAccessor.
unittest
{
    auto index = Index(false, false);

    auto translUnit = TranslationUnit.parse(
        index,
        "test_files/include/file.h",
        []);

    auto query = translUnit.relativeLocationAccessor;

    assert(
        query(translUnit.location("test_files/include/file.h", 0)) ==
        query(translUnit.location("test_files/include/file.h", 0)));

    assert(
        query(translUnit.location("test_files/include/file.h", 0)) <
        query(translUnit.location("test_files/include/file.h", 27)));

    assert(
        query(translUnit.location("test_files/include/file.h", 0)) <
        query(translUnit.location("test_files/include/file.h", 1)));

    assert(
        query(translUnit.location("test_files/include/file.h", 0)) <
        query(translUnit.location("test_files/include/subfile1.h", 1)));

    assert(
        query(translUnit.location("test_files/include/subfile1.h", 13)) <
        query(translUnit.location("test_files/include/subfile1.h", 14)));

    assert(
        query(translUnit.location("test_files/include/subfile1.h", 13)) <
        query(translUnit.location("test_files/include/subsubfile1.h", 10)));

    assert(
        query(translUnit.location("test_files/include/file.h", 53)) <
        query(translUnit.location("test_files/include/file.h", 79)));

    assert(
        query(translUnit.location("test_files/include/file.h", 78)) <
        query(translUnit.location("test_files/include/file.h", 79)));

    assert(
        query(translUnit.location("test_files/include/subfile3.h", 1)) <
        query(translUnit.location("test_files/include/file.h", 76)));

    assert(
        query(translUnit.location("test_files/include/subfile3.h", 1)) >
        query(translUnit.location("test_files/include/file.h", 75)));
}

// Test TranslationUnit.allInOrder.
unittest
{
    auto translUnit = makeTranslationUnit(
    q"C
#include <stdlib.h>

int a;

#define FOO = 0

int b;

#define BAR = 0;

int c;

#include <stdlib.h>

int d;

const int var = FOO;

#ifdef FOO

#endif

C");

  // CXCursor_PreprocessingDirective        = 500,
  // CXCursor_MacroDefinition               = 501,
  // CXCursor_MacroExpansion                = 502,
  // CXCursor_InclusionDirective            = 503,

    import std.algorithm.iteration;
    import std.array;
    import std.stdio;

    auto main = translUnit.file;

    auto children = translUnit.cursor.childrenInOrder.filter!(a => a.file == main).array;

    assert(children[0].kind == CXCursorKind.CXCursor_InclusionDirective);
    assert(children[1].kind == CXCursorKind.CXCursor_VarDecl);
    assert(children[2].kind == CXCursorKind.CXCursor_MacroDefinition);
    assert(children[3].kind == CXCursorKind.CXCursor_VarDecl);
    assert(children[4].kind == CXCursorKind.CXCursor_MacroDefinition);
    assert(children[5].kind == CXCursorKind.CXCursor_VarDecl);
    assert(children[6].kind == CXCursorKind.CXCursor_InclusionDirective);
    assert(children[7].kind == CXCursorKind.CXCursor_VarDecl);
    assert(children[8].kind == CXCursorKind.CXCursor_VarDecl);
    assert(children[9].kind == CXCursorKind.CXCursor_MacroExpansion);
    assert(children[10].kind == CXCursorKind.CXCursor_MacroExpansion);
}
