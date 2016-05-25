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

import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.Type;

class Record : Declaration
{
    static bool[Cursor] recordDefinitions;

    this (Cursor cursor, Cursor parent, Translator translator)
    {
        super(cursor, parent, translator);
    }

    override void translate (Output output)
    {
        if (cursor.isDefinition)
            translateDefinition(output);
        else
            translateForwardDeclaration(output);
    }

    private void translateDefinition(Output output)
    {
        import std.format;

        this.recordDefinitions[cursor] = true;

        auto name = spelling == "" ? spelling : " " ~ spelling;

        output.subscopeStrong(format("%s%s", type, name)) in {
            foreach (cursor, parent; cursor.declarations)
            {
                with (CXCursorKind)
                    switch (cursor.kind)
                    {
                        case CXCursor_FieldDecl:
                            output.flushLocation(cursor);

                            if (!cursor.type.isExposed && cursor.type.declaration.isValid)
                            {
                                auto def = cursor.type.declaration.definition;
                                auto known = def in this.recordDefinitions;

                                if (!known)
                                    translator.translate(output, cursor.type.declaration);

                                if (cursor.type.declaration.type.isEnum ||
                                    !cursor.type.isAnonymous)
                                    translateVariable(output, cursor);
                            }

                            else
                                translateVariable(output, cursor);
                        break;

                        default: break;
                    }
            }
        };
    }

    private void translateForwardDeclaration(Output output)
    {
        output.singleLine("struct %s;", spelling);
    }

    private void translateVariable (Output output, Cursor cursor)
    {
        translator.variable(output, cursor);
    }

    private string type ()
    {
        switch (cursor.kind)
        {
            case CXCursorKind.CXCursor_UnionDecl:
                return "union";
            default:
                return "struct";
        }
    }
}
