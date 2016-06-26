/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

module clang.SourceRange;

import std.conv;
import clang.c.Index;
import clang.SourceLocation;
import clang.Util;

struct SourceRange
{
    mixin CX;

    @property SourceLocation start() const
    {
        return SourceLocation(clang_getRangeStart(cx));
    }

    @property SourceLocation end() const
    {
        return SourceLocation(clang_getRangeEnd(cx));
    }

    @property bool isMultiline() const
    {
        return start.line != end.line;
    }

    @property string path() const
    {
        return start.path;
    }

    @property string toString() const
    {
        import std.format: format;
        return format("SourceRange(start = %s, end = %s)", start, end);
    }
}

bool intersects(in SourceRange a, in SourceRange b)
{
    return a.path == b.path &&
        (a.start.offset <= b.start.offset && b.start.offset < a.end.offset) ||
        (a.start.offset < b.end.offset && b.end.offset <= a.end.offset);
}
