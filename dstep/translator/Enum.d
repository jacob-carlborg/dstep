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

import dstep.translator.Context;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.Type;

void translateEnumConstantDecl(Output output, Context context, Cursor cursor, bool last)
{
    import std.format : format;

    output.singleLine(
        cursor.extent,
        "%s = %s%s",
        cursor.spelling,
        cursor.enum_.value,
        last ? "" : ",");
}

void generateEnumAliases(Output output, Context context, Cursor cursor, string spelling)
{
    string subscope = cursorScopeString(context, cursor) ~ ".";

    foreach (item; cursor.all)
    {
        switch (item.kind)
        {
            case CXCursorKind.CXCursor_EnumConstantDecl:
                output.singleLine(
                    "alias %s = %s%s;",
                    item.spelling,
                    subscope,
                    item.spelling);
                break;

            default:
                break;
        }
    }
}

void translateEnumDef(Output output, Context context, Cursor cursor)
{
    import std.format : format;

    auto variables = cursor.variablesInParentScope();
    auto anonymous = context.shouldBeAnonymous(cursor);
    auto spelling = "enum";

    if (!anonymous || variables || !cursor.isGlobal)
        spelling = "enum " ~ translateIdentifier(context.translateTagSpelling(cursor));

    output.subscopeStrong(cursor.extent, "%s", spelling) in
    {
        auto children = cursor.children;

        foreach (i; 0..children.length)
        {
            with (CXCursorKind)
            {
                switch (children[i].kind)
                {
                    case CXCursor_EnumConstantDecl:
                        translateEnumConstantDecl(
                            output,
                            context,
                            children[i],
                            children.length == i + 1);
                        break;

                    default:
                        break;
                }
            }
        }
    };

    if ((anonymous && variables) || !cursor.isGlobal)
        generateEnumAliases(context.globalScope, context, cursor, spelling);
}

void translateEnum(Output output, Context context, Cursor cursor)
{
    auto canonical = cursor.canonical;

    if (!context.alreadyDefined(cursor.canonical))
    {
        translateEnumDef(output, context, canonical.definition);
        context.markAsDefined(cursor);
    }
}
