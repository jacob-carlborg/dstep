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
        Spelling spell;

        clang_getExpansionLocation(cx, &spell.file.cx, &spell.line, &spell.column, &spell.offset);

        return spell;
    }

    @property string path() const
    {
        File file;
        clang_getExpansionLocation(cx, &file.cx, null, null, null);
        return file.name;
    }

    @property uint line() const
    {
        uint result;
        clang_getExpansionLocation(cx, null, &result, null, null);
        return result;
    }

    @property uint column() const
    {
        uint result;
        clang_getExpansionLocation(cx, null, null, &result, null);
        return result;
    }

    @property uint offset() const
    {
        uint result;
        clang_getExpansionLocation(cx, null, null, null, &result);
        return result;
    }

    @property bool isFromMainFile() const
    {
        return clang_Location_isFromMainFile(cx) != 0;
    }

    @property string toString() const
    {
        import std.format: format;
        auto s = spelling;
        return format("SourceLocation(file = %s, line = %d, column = %d, offset = %d)", s.file, s.line, s.column, s.offset);
    }

    bool lexicalLess(in SourceLocation that)
    {
        File fileA, fileB;
        uint offsetA, offsetB;

        clang_getSpellingLocation(cx, &fileA.cx, null, null, &offsetA);
        clang_getSpellingLocation(that.cx, &fileB.cx, null, null, &offsetB);

        return fileA != fileB ? fileA < fileB : offsetA < offsetB;
    }
}
