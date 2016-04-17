/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.SourceLocation;

import clang.c.Index;
import clang.File;
import clang.Util;

struct SourceLocation
{
    mixin CX;

    struct Spelling
    {
        File file;
        uint line;
        uint column;
        uint offset;
    }

    @property Spelling spelling() const
    {
        Spelling spell;

        clang_getSpellingLocation(cx, &spell.file.cx, &spell.line, &spell.column, &spell.offset);

        return spell;
    }

    @property Spelling expansion() const
    {
        Spelling spell;

        clang_getExpansionLocation(cx, &spell.file.cx, &spell.line, &spell.column, &spell.offset);

        return spell;
    }

    @property size_t offset() const
    {
        return spelling.offset;
    }

    @property string path() const
    {
        return spelling.file.name;
    }

    @property string toString() const
    {
        import std.format: format;
        auto s = spelling;
        return format("SourceLocation(file = %s, line = %d, column = %d, offset = %d)", s.file, s.line, s.column, s.offset);
    }

    static bool lexicalLess(in SourceLocation a, in SourceLocation b)
    {
        File fileA, fileB;
        uint offsetA, offsetB;

        clang_getSpellingLocation(a.cx, &fileA.cx, null, null, &offsetA);
        clang_getSpellingLocation(b.cx, &fileB.cx, null, null, &offsetB);

        return fileA != fileB ? fileA < fileB : offsetA < offsetB;
    }
}
