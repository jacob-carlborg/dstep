/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 6, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.objc.Category;

import mambo.core._;

import clang.Cursor;
import clang.Type;

import dstep.translator.Declaration;
import dstep.translator.objc.ObjcInterface;
import dstep.translator.Output;
import dstep.translator.Translator;

class Category : ObjcInterface!(ClassExtensionData)
{
    this (Cursor cursor, Cursor parent, Translator translator)
    {
        super(cursor, parent, translator);
    }

    protected override string[] collectInterfaces (ObjcCursor cursor)
    {
        auto interfaces = super.collectInterfaces(cursor);
        auto category = translateIdentifier(cursor.category.spelling);

        return category ~ interfaces;
    }
}