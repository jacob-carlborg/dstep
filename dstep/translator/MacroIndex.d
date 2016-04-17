/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Mar 08, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

module dstep.translator.MacroIndex;

import std.container.rbtree;

import clang.c.Index;
import clang.Cursor;
import clang.SourceLocation;
import clang.SourceRange;
import clang.TranslationUnit;

class InvalidArgumentError : object.Error
{
    this (string message, string file = __FILE__, ulong line = __LINE__)
    {
        super(message, file, line);
    }
}

class MacroIndex
{
    private static bool pred(in Cursor a, in Cursor b)
    {
        return SourceLocation.lexicalLess(a.location, b.location);
    }

    private TranslationUnit unit;
    private alias CursorRedBlackTree = RedBlackTree!(Cursor, (in Cursor a, in Cursor b) => pred(a, b));
    private CursorRedBlackTree expansions;
    private Cursor[string] definitions;

    private static string uniqueID(in Cursor cursor)
    {
        import std.format : format;
        return "%s@%s:%d".format(cursor.spelling, cursor.location.path, cursor.location.offset);
    }

    this(TranslationUnit unit)
    {
        import std.stdio;

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

    Cursor queryDefinition(in Cursor expansion) const
    {
        if (expansion.kind != CXCursorKind.CXCursor_MacroExpansion)
            throw new InvalidArgumentError("`expansion` is required to be MacroExpansion.");

        return definitions[uniqueID(expansion)];
    }

    Cursor[] queryExpansion(Cursor cursor) const
    {
        import std.array : array;

        SourceRange extent = cursor.extent;
        Cursor[] result;

        auto equal = expansions.equalRange(cursor);
        auto greater = expansions.upperBound(cursor);

        if (!equal.empty)
            result ~= equal.array;

        foreach (itr; greater)
        {
            if (itr.file == cursor.file && itr.location.offset < extent.end.offset)
                result ~= itr;
            else
                break;
        }

        return result;
    }
}
