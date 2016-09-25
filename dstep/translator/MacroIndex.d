/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Mar 08, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.MacroIndex;

import std.typecons;
import std.algorithm;
import std.range;

import clang.c.Index;
import clang.Cursor;
import clang.SourceLocation;
import clang.SourceRange;
import clang.Token;
import clang.TranslationUnit;

import dstep.translator.Preprocessor;

class MacroIndex
{
    private TranslationUnit translUnit;
    private bool delegate (Cursor, Cursor) lessOp;
    private Cursor[] expansions;
    private Cursor[string] globalCursors_;
    private Directive[] directives;

    this(TranslationUnit translUnit)
    {
        this.translUnit = translUnit;

        auto expansionsAppender = appender!(Cursor[])();

        foreach (cursor, parent; translUnit.cursor.all)
        {
            if (cursor.kind == CXCursorKind.CXCursor_MacroExpansion)
                expansionsAppender.put(cursor);

            if (!cursor.spelling.empty)
                globalCursors_[extendedSpelling(cursor)] = cursor;
        }

        lessOp = translUnit.relativeCursorLocationLessOp();
        expansions = expansionsAppender.data.sort!((a, b) => lessOp(a, b)).array;
        directives = dstep.translator.Preprocessor.directives(translUnit);
    }

    static string extendedSpelling(Cursor cursor)
    {
        import std.format : format;

        switch (cursor.kind)
        {
            case CXCursorKind.CXCursor_StructDecl:
                return format("struct %s", cursor.spelling);

            case CXCursorKind.CXCursor_UnionDecl:
                return format("union %s", cursor.spelling);

            case CXCursorKind.CXCursor_EnumDecl:
                return format("enum %s", cursor.spelling);

            default:
                return cursor.spelling;
        }
    }

    Cursor[] queryExpansion(Cursor cursor) const
    {
        import std.array;
        import std.algorithm.searching;

        SourceRange extent = cursor.extent;

        auto expansionsSorted = expansions.assumeSorted!((a, b) => lessOp(a, b));

        auto equal = expansionsSorted.equalRange(cursor);
        auto greater = expansionsSorted.upperBound(cursor);

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

    Cursor[string] globalCursors()
    {
        return globalCursors_;
    }
}
