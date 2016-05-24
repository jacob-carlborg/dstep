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

class Record (Data) : Declaration
{
    static bool[Cursor] recordDefinitions;

    this (Cursor cursor, Cursor parent, Translator translator)
    {
        super(cursor, parent, translator);
    }

    override void translate (Output output)
    {
        writeRecord(output, spelling, (context) {
            foreach (cursor, parent ; cursor.declarations)
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
                                {
                                    Output output = new Output();
                                    translator.translate(output, cursor.type.declaration);
                                    context.instanceVariables ~= output;
                                }

                                if (cursor.type.declaration.type.isEnum || !cursor.type.isAnonymous)
                                    translateVariable(cursor, context);
                            }

                            else
                                translateVariable(cursor, context);
                        break;

                        default: break;
                    }
            }
        });
    }

private:

    void writeRecord (Output output, string name, void delegate (Data context) dg)
    {
        auto context = new Data(translator.context);

        if (cursor.isDefinition)
            this.recordDefinitions[cursor] = true;
        else
            context.isFwdDeclaration = true;

        context.name = translateIdentifier(name);

        dg(context);

        output.output(context.data);
    }

    void translateVariable (Cursor cursor, Data context)
    {
        Output output = new Output();
        translator.variable(output, cursor);
        context.instanceVariables ~= output;
    }
}
