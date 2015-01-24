/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 1, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Record;

import mambo.core._;

import clang.c.index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Translator;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Type;

class Record (Data) : Declaration
{
    this (Cursor cursor, Cursor parent, Translator translator)
    {
        super(cursor, parent, translator);
    }

    override string translate ()
    {
        return writeRecord(spelling, (context) {
            foreach (cursor, parent ; cursor.declarations)
            {
                with (CXCursorKind)
                    switch (cursor.kind)
                    {
                        case CXCursor_FieldDecl:
                            if (!cursor.type.isExposed && cursor.type.declaration.isValid)
                            {
                                output.newContext();
                                output.currentContext.indent in {
                                    context.instanceVariables ~= translator.translate(cursor.type.declaration);
                                };

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

    string writeRecord (string name, void delegate (Data context) dg)
    {
        auto context = new Data;
        static if (is(typeof(context.isFwdDeclaration) == bool))
            context.isFwdDeclaration = !cursor.isDefinition;
        context.name = translateIdentifier(name);

        dg(context);

        return context.data;
    }

    void translateVariable (Cursor cursor, Data context)
    {
        output.newContext();
        context.instanceVariables ~= translator.variable(cursor);
    }
}
