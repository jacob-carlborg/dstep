/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 1, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Record;

import std.algorithm.mutation;

import clang.c.Index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Context;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.Type;

string translateRecordType(in Cursor cursor)
{
    if (cursor.kind == CXCursorKind.CXCursor_UnionDecl)
        return "union";
    else
        return "struct";
}

void translateRecordDef(Output output, Context context, Cursor cursor, bool keepUnnamed = false)
{
    auto canonical = cursor.canonical;
    auto typedefp = context.typedefParent(canonical);

    import std.format;

    auto spelling = keepUnnamed ? "" : context.translateSpelling(cursor);
    spelling = spelling == "" ? spelling : " " ~ spelling;
    auto type = translateRecordType(cursor);

    output.subscopeStrong(cursor.extent, "%s%s", type, spelling) in {
        foreach (cursor, parent; cursor.declarations)
        {
            with (CXCursorKind)
                switch (cursor.kind)
                {
                    case CXCursor_FieldDecl:
                        output.flushLocation(cursor);

                        if (!cursor.type.isExposed && cursor.type.declaration.isValid)
                        {
                            context.translator.translate(
                                output,
                                cursor.type.declaration);

                            translateVariable(output, context, cursor);
                        }
                        else
                            translateVariable(output, context, cursor);

                        break;

                    case CXCursor_UnionDecl:
                    case CXCursor_StructDecl:
                        if (cursor.type.isAnonymous)
                            translateAnonymousRecord(output, context, cursor, parent);

                        break;

                    default: break;
                }
        }
    };
}

void translateRecordDecl(Output output, Context context, Cursor cursor)
{
    auto spelling = context.translateSpelling(cursor);
    spelling = spelling == "" ? spelling : " " ~ spelling;
    auto type = translateRecordType(cursor);
    output.singleLine(cursor.extent, "%s%s;", type, spelling);
}

void translateAnonymousRecord(Output output, Context context, Cursor cursor, Cursor parent)
{
    import std.algorithm.iteration : filter;
    import std.stdio;

    auto canonical = cursor.canonical;

    bool predicate(Cursor a)
    {
        return a.kind == CXCursorKind.CXCursor_FieldDecl &&
            a.type.declaration.canonical == canonical;
    }

    auto fields = filter!(predicate)(parent.children);

    if (fields.empty)
        translateRecordDef(output, context, cursor, true);
}

void translateRecord(Output output, Context context, Cursor cursor)
{
    auto canonical = cursor.canonical;

    if (!context.alreadyDefined(cursor.canonical))
    {
        auto definition = canonical.definition;

        if (definition.isValid)
            translateRecordDef(output, context, definition);
        else
            translateRecordDecl(output, context, cursor);

        context.markAsDefined(cursor);
    }
}
