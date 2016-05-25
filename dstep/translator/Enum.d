/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 10, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Enum;

import clang.c.Index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Translator;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Type;

class Enum : Declaration
{
    private string aliasName;

    this (Cursor cursor, Cursor parent, Translator translator, string aliasName)
    {
        super(cursor, parent, translator);
        this.aliasName = aliasName;
    }

    override void translate (Output output)
    {
        import std.format : format;

        output.subscopeStrong(
            cursor.extent,
            "enum %s",
            translateIdentifier(spelling)) in
        {
            auto children = cursor.children;

            foreach (i; 0 .. children.length)
            {
                with (CXCursorKind)
                {
                    switch (children[i].kind)
                    {
                        case CXCursor_EnumConstantDecl:
                            translateEnumConstantDecl(
                                output,
                                children[i],
                                children.length == i + 1);
                            break;

                        default:
                            break;
                    }
                }
            }
        };
    }

    void translateEnumConstantDecl(Output output, Cursor cursor, bool last)
    {
        import std.format : format;

        output.singleLine(
            cursor.extent,
            "%s = %s%s",
            cursor.spelling,
            cursor.enum_.value,
            last ? "" : ",");
    }

    string anonymous()
    {
        return translator.context.generateAnonymousName(cursor);
    }

    @property override string spelling ()
    {
        auto name = cursor.spelling;

        if (name != "")
            return name;
        else
            return aliasName == "" ? anonymous : aliasName;
    }
}