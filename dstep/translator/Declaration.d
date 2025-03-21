/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Declaration;

import clang.Cursor;

import dstep.translator.Translator;
import dstep.translator.Output;
import dstep.translator.Util;

abstract class Declaration
{
    protected
    {
        Cursor cursor;
        Cursor parent;

        Translator translator;
    }

    template Constructors ()
    {
        import clang.Cursor;
        import dstep.translator.Output;

        this (Cursor cursor, Cursor parent, Translator translator)
        {
            super(cursor, parent, translator);
        }
    }

    this (Cursor cursor, Cursor parent, Translator translator)
    {
        this.cursor = cursor;
        this.parent = parent;
        this.translator = translator;
    }

    abstract void translate (Output output);

    @property string spelling ()
    {
        auto name = cursor.spelling;
        return !name.isUnnamed && (name.length || parent.isEmpty) ? name : translator.context.generateAnonymousName(cursor);
    }
}
