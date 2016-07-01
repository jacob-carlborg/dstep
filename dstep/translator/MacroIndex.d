/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Mar 08, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.MacroIndex;

import std.container.rbtree;
import std.typecons;

import clang.c.Index;
import clang.Cursor;
import clang.SourceLocation;
import clang.SourceRange;
import clang.Token;
import clang.TranslationUnit;

class MacroIndex
{
    private static bool pred(in Cursor a, in Cursor b)
    {
        return a.location.lexicalLess(b.location);
    }

    private TranslationUnit unit;
    private alias CursorRedBlackTree =
        RedBlackTree!(Cursor, (a, b) => pred(a, b));
    private CursorRedBlackTree expansions;
    private Cursor[string] definitions;

    private static string uniqueID(in Cursor cursor)
    {
        import std.format : format;
        return format(
            "%s@%s:%d",
            cursor.spelling,
            cursor.location.path,
            cursor.location.offset);
    }

    this(TranslationUnit unit)
    {
        this.unit = unit;

        expansions = new CursorRedBlackTree();

        Cursor[string] recent;

        foreach (cursor, parent; unit.cursor.all)
        {
            if (cursor.kind == CXCursorKind.CXCursor_MacroExpansion)
            {
                expansions.insert(cursor);

                Cursor* def = cursor.spelling in recent;

                if (def !is null)
                    definitions[uniqueID(cursor)] = *def;
            }
            else if (cursor.kind == CXCursorKind.CXCursor_MacroDefinition)
            {
                recent[cursor.spelling] = cursor;
            }
        }
    }

    Cursor[] queryExpansion(Cursor cursor) const
    {
        import std.array;
        import std.algorithm.searching;

        SourceRange extent = cursor.extent;

        auto equal = expansions.equalRange(cursor);
        auto greater = expansions.upperBound(cursor);

        auto result = appender!(Cursor[])();

        if (!equal.empty)
            result ~= equal.array;

        result ~= until
            !(itr => itr.file != cursor.file ||
            itr.location.offset >= extent.end.offset)
            (greater, OpenRight.yes);

        return result.data;
    }
}
