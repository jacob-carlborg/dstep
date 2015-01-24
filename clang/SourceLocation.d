/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.SourceLocation;

import clang.c.index;
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

    @property Spelling spelling ()
    {
        Spelling spell;

        clang_getSpellingLocation(cx, &spell.file.cx, &spell.line, &spell.column, &spell.offset);

        return spell;
    }
}