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

import dstep.translator.Preprocessor;

class MacroIndex
{
    private static bool pred(in Cursor a, in Cursor b)
    {
        return a.location.lexicalLess(b.location);
    }

    private TranslationUnit translUnit;
    private alias CursorRedBlackTree =
        RedBlackTree!(Cursor, (a, b) => pred(a, b));
    private CursorRedBlackTree expansions;
    private Cursor[string] definitions;

    private Directive[] directives;

    private static string uniqueID(in Cursor cursor)
    {
        import std.format : format;
        return format(
            "%s@%s:%d",
            cursor.spelling,
            cursor.location.path,
            cursor.location.offset);
    }

    this(TranslationUnit translUnit)
    {
        this.translUnit = translUnit;

        expansions = new CursorRedBlackTree();

        Cursor[string] recent;

        foreach (cursor, parent; translUnit.cursor.all)
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

        directives = dstep.translator.Preprocessor.directives(translUnit);
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

    Tuple!(bool, SourceLocation) includeGuardLocation()
    {
        import std.range.primitives : empty;

        static bool checkIfndef(ConditionalDirective directives, string identifier)
        {
            auto negation = cast (UnaryExpr) directives.condition;

            if (negation && negation.operator == "!")
            {
                auto defined = cast (DefinedExpr) negation.subexpr;
                return defined && defined.identifier == identifier;
            }

            return false;
        }

        if (!directives.empty)
        {
            if (directives[0].kind == DirectiveKind.pragmaOnce)
            {
                return Tuple!(bool, SourceLocation)(true, directives[0].extent.start);
            }
            else if (2 <= directives.length)
            {
                auto ifndef = cast (ConditionalDirective) directives[0];
                auto define = cast (MacroDefinition) directives[1];
                auto endif = directives[$ - 1];

                if (ifndef && define &&
                    ifndef.endif == endif &&
                    checkIfndef(ifndef, define.spelling))
                    return Tuple!(bool, SourceLocation)(true, ifndef.location);
            }
        }

        return Tuple!(bool, SourceLocation)(false, SourceLocation.empty);
    }
}
