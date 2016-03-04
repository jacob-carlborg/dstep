/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 10, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Enum;

import mambo.core._;

import clang.c.Index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.CodeBlock;
import dstep.translator.Translator;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Type;

class Enum : Declaration
{
    this (Cursor cursor, Cursor parent, Translator translator)
    {
        super(cursor, parent, translator);
    }

    override CodeBlock translate ()
    {
        import std.format : format;

        CodeBlock result = CodeBlock(
            "enum %s".format(translateIdentifier(spelling)),
            EndlHint.subscopeStrong);


        foreach (cursor, parent; cursor.declarations)
        {
            with (CXCursorKind)
            {
                switch (cursor.kind)
                {
                    case CXCursor_EnumConstantDecl:
                        result.children ~= translateEnumConstantDecl(cursor);
                        break;

                    default:
                        break;
                }
            }
        }

        if (result.children.length != 0)
            result.children[$-1].spelling = result.children[$-1].spelling[0..$-1];

        return result;
    }

    CodeBlock translateEnumConstantDecl(Cursor cursor)
    {
        import std.format : format;
        return CodeBlock("%s = %s,".format(cursor.spelling, cursor.enum_.value));
    }

    @property override string spelling ()
    {
        auto name = cursor.spelling;
        return name.isPresent ? name : generateAnonymousName(cursor);
    }
}