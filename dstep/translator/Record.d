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
import dstep.translator.Enum;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.Type;

string translateRecordTypeKeyword(in Cursor cursor)
{
    if (cursor.kind == CXCursorKind.CXCursor_UnionDecl)
        return "union";
    else
        return "struct";
}

void translatePackedAttribute(Output output, Context context, Cursor cursor)
{
    if (auto attribute = cursor.findChild(CXCursorKind.CXCursor_PackedAttr))
        output.singleLine("align (1):");
}

void translateRecordDef(
    Output output,
    Context context,
    Cursor cursor,
    bool keepUnnamed = false)
{
    auto canonical = cursor.canonical;

    import std.format;

    auto spelling = keepUnnamed ? "" : context.translateSpelling(cursor);
    spelling = spelling == "" ? spelling : " " ~ spelling;
    auto type = translateRecordTypeKeyword(cursor);

    output.subscopeStrong(cursor.extent, "%s%s", type, spelling) in {

        translatePackedAttribute(output, context, cursor);

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
                        }
                        else if (cursor.type.isDecorated)
                        {
                            context.translator.translate(
                                output,
                                cursor.type.undecorated.declaration);
                        }

                        translateVariable(output, context, cursor);

                        break;

                    case CXCursor_UnionDecl:
                    case CXCursor_StructDecl:
                        if (cursor.type.isAnonymous)
                            translateAnonymousRecord(output, context, cursor, parent);

                        break;

                    case CXCursor_EnumDecl:
                        translateEnum(output, context, cursor);
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
    auto type = translateRecordTypeKeyword(cursor);
    output.singleLine(cursor.extent, "%s%s;", type, spelling);
}

void translateAnonymousRecord(Output output, Context context, Cursor cursor, Cursor parent)
{
    if (!variablesInParentScope(cursor))
        translateRecordDef(output, context, cursor, true);
}

bool shouldSkipRecord(Context context, Cursor cursor)
{
    if (cursor.kind == CXCursorKind.CXCursor_StructDecl ||
        cursor.kind == CXCursorKind.CXCursor_UnionDecl)
    {
        auto typedefp = context.typedefParent(cursor.canonical);
        auto spelling = typedefp.isValid && cursor.spelling == ""
            ? typedefp.spelling
            : cursor.spelling;

        return context.options.skipSymbols.contains(spelling);
    }

    return false;
}

bool shouldSkipRecordDefinition(Context context, Cursor cursor)
{
    if (cursor.kind == CXCursorKind.CXCursor_StructDecl ||
        cursor.kind == CXCursorKind.CXCursor_UnionDecl)
    {
        auto typedefp = context.typedefParent(cursor.canonical);
        auto spelling = typedefp.isValid && cursor.spelling == ""
            ? typedefp.spelling
            : cursor.spelling;

        return context.options.skipDefinitions.contains(spelling);
    }

    return false;
}

void translateRecord(Output output, Context context, Cursor cursor)
{
    auto canonical = cursor.canonical;

    if (!context.alreadyDefined(cursor.canonical))
    {
        auto definition = canonical.definition;

        if (definition.isValid && !shouldSkipRecordDefinition(context, cursor))
            translateRecordDef(output, context, definition);
        else
            translateRecordDecl(output, context, cursor);

        context.markAsDefined(cursor);
    }
}
