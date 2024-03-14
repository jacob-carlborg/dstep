/**
 * Copyright: Copyright (c) 2024 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Mar 14, 2024
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.ApiNotesTranslator;

import std.format;

import clang.Cursor;

import dstep.core.Core;
import dstep.core.Optional;
import dstep.core.Exceptions;
import dstep.translator.ApiNotes;
import dstep.translator.Context;
import dstep.translator.Output;
import dstep.translator.Translator;

private alias Function = dstep.translator.ApiNotes.Function;

struct ApiNotesTranslator
{
    private Context context;

    this(Context context)
    {
        this.context = context;
    }

    void freeFunctionToInstanceMethod(Cursor cursor, string name, Function func)
    {
        context.addAnnotatedMember(func.context.or(""), (Output output) {
            const declName = "__" ~ name;

            auto wrapperFunction = dstep.translator.Translator.Function(
                cursor: cursor.func,
                name: name,
                apiNotesFunction: func.some
            );

            auto wrapperResult = translateFunction(context, wrapperFunction);

            assert(cursor.func.parameters.length > 0,
                "there needs to be at least one parameter for instance methods");
            const firstParamType = cursor.func.parameters.first.type;
            const thisArg = firstParamType.isPointer ? "&this" : "this";

            output.subscopeStrong(wrapperResult.extent, wrapperResult.makeString) in {
                output.singleLine("return %s(%s, __traits(parameters));", declName, thisArg);
            };

            addBindingFunction(cursor, output, declName);
        });
    }

    void freeFunctionToConstructor(Cursor cursor, Function func)
    {
        auto previousOriginalType = context
            .getAnnotatedCursorFor(func.context.or(""))
            .func.resultType;

        if (previousOriginalType.isPresent &&
            !previousOriginalType.get.isEqualTo(cursor.func.resultType))
        {
            const message = format!("Already specified a constructor with " ~
                "a different type. Previous type: %s. New type: %s")(
                    previousOriginalType.get.spelling,
                    cursor.func.resultType.spelling
            );

            throw new DStepException(message);
        }

        context.setAnnotatedCursorFor(func.context.or(""), cursor);

        context.addAnnotatedMember(func.context.or(""), (Output output) {
            auto wrapperFunction = dstep.translator.Translator.Function(
                cursor: cursor.func,
                name: "opCall",
                apiNotesFunction: func.some,
                isStatic: true
            );

            auto wrapperResult = translateFunction(context, wrapperFunction);
            const translatedName = translateIdentifier(cursor.spelling);

            output.subscopeStrong(wrapperResult.extent, wrapperResult.makeString) in {
                output.singleLine("return %s(__traits(parameters));", translatedName);
            };

            addBindingFunction(cursor, output, translatedName);
        });
    }

    void freeFunctionToStaticMethod(Cursor cursor, string name, Function func)
    {
        context.addAnnotatedMember(func.context.or(""), (Output output) {
            auto function_ = dstep.translator.Translator.Function(
                cursor: cursor.func,
                name: name,
                mangledName: none!string, // handle below
                apiNotesFunction: func.some,
                isStatic: true
            );

            auto result = translateFunction(context, function_);
            output.singleLine(`extern (C) pragma(mangle, "%s")`, cursor.mangling);
            output.adaptiveSourceNode(result);
            output.append(";");
        });
    }

private:

    void addBindingFunction(Cursor cursor, Output output, string declName)
    {
        auto function_ = dstep.translator.Translator.Function(
            cursor: cursor.func,
            name: declName,
            mangledName: none!string, // handle below
        );

        auto declarationResult = translateFunction(context, function_);

        output.singleLine(`extern (C) private static pragma(mangle, "%s")`, cursor.mangling);
        output.adaptiveSourceNode(declarationResult);
        output.append(";");
    }
}
