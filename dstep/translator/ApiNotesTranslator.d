/**
 * Copyright: Copyright (c) 2024 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Mar 14, 2024
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.ApiNotesTranslator;

import std.algorithm;
import std.format;
import std.functional;

import clang.c.Index;
import clang.Cursor;
import clang.SourceRange;

import dstep.core.Core;
import dstep.core.Optional;
import dstep.core.Exceptions;
import dstep.core.Set;
import dstep.translator.ApiNotes;
import dstep.translator.Context;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.Type;

private alias Function = dstep.translator.ApiNotes.Function;

struct ApiNotesTranslator
{
    AnnotatedDeclaration[string] declarations;

    private Context context;
    private Set!string declarationsNeedingWrapping;
    private ApiNotes apiNotes;

    this(Context context, ApiNotes apiNotes)
    {
        this.context = context;
        this.apiNotes = apiNotes;
        collectDeclarationsNeedingWrapping();
    }

    void addDeclaration(StructData structData)
    {
        declarations.require(structData.name, new AnnotatedDeclaration(structData.name)).
            declaration = structData;
    }

    void freeFunctionToInstanceMethod(Cursor cursor, string name, Function func)
    {
        auto member = (Output output) {
            const originalName = "__" ~ name;

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


            string[] parameterNames;
            parameterNames.reserve(cursor.func.parameters.length);
            size_t paramCount;

            foreach (param ; cursor.func.parameters)
            {
                if (paramCount == func.indexOfThis)
                    parameterNames ~= param.type.isPointer ? "&this" : "this";
                else
                    parameterNames ~= translateIdentifier(param.spelling);

                paramCount++;
            }

            output.subscopeStrong(wrapperResult.extent, wrapperResult.makeString) in {
                output.singleLine("return %s(%-(%s, %));", originalName, parameterNames);
            };

            addOriginalFunction(cursor, output, originalName);
        };

        addMember(member, for_: func.context.or(""));
    }

    void freeFunctionToConstructor(Cursor cursor, Function func)
    {
        auto previousOriginalType = getCursor(for_: func.context.or(""))
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

        setCursor(cursor, for_: func.context.or(""));

        auto member = (Output output) {
            auto wrapperFunction = dstep.translator.Translator.Function(
                cursor: cursor.func,
                name: "opCall",
                apiNotesFunction: func.some,
                isStatic: true
            );

            auto wrapperResult = translateFunction(context, wrapperFunction);
            const translatedName = translateIdentifier(cursor.spelling);

            output.subscopeStrong(wrapperResult.extent, wrapperResult.makeString) in {
                if (func.context.or("") in declarationsNeedingWrapping)
                {
                    output.singleLine("typeof(this) __result = { %s(__traits(parameters)) };", translatedName);
                    output.singleLine("return __result;");
                }

                else
                    output.singleLine("return %s(__traits(parameters));", translatedName);
            };

            addOriginalFunction(cursor, output, translatedName);
        };

        addMember(member, for_: func.context.or(""));
    }

    void freeFunctionToStaticMethod(Cursor cursor, string name, Function func)
    {
        auto member = (Output output) {
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
        };

        addMember(member, for_: func.context.or(""));
    }

    void synthesisDeclarations()
    {
        foreach (ad; declarationsNeedingSynthesizing)
        {
            assert(ad.cursor.isPresent);
            auto cursor = ad.cursor.get;
            auto type = translateType(context, cursor, cursor.func.resultType.canonical);

            StructData.Body body = (output) {
                translateVariable(output, type,
                    identifier: "__rawValue", prefix: "private ");
            };

            auto extent = SourceRange(clang_getNullRange());
            addDeclaration(new StructData(ad.name, "struct", extent, body));
        }
    }

private:

    auto declarationsNeedingSynthesizing() =>
        declarations.byValue.filter!(e => e.declaration.empty);

    void addOriginalFunction(Cursor cursor, Output output, string declName)
    {
        auto function_ = dstep.translator.Translator.Function(
            cursor: cursor.func,
            name: declName,
            mangledName: none!string, // handle below
            canonicalizeReturnType: true
        );

        auto declarationResult = translateFunction(context, function_);

        output.singleLine(`extern (C) private static pragma(mangle, "%s")`, cursor.mangling);
        output.adaptiveSourceNode(declarationResult);
        output.append(";");
    }

    void addMember(StructData.Body member, string for_)
    {
        auto name = for_;
        declarations.require(name, new AnnotatedDeclaration(name))
            .addMember(member);
    }

    void setCursor(Cursor cursor, string for_)
    {
        auto name = for_;
        declarations.require(name, new AnnotatedDeclaration(name))
            .cursor = cursor;
    }

    Optional!Cursor getCursor(string for_)
    {
        auto name = for_;
        return declarations
            .get(name, new AnnotatedDeclaration(name))
            .cursor;
    }

    void collectDeclarationsNeedingWrapping()
    {
        alias isAggregate = e =>
            e.kind == CXCursorKind.structDecl ||
            e.kind == CXCursorKind.unionDecl;

        context
            .translUnit
            .cursor
            .children
            .filter!(cursor => cursor.isDeclaration)
            .filter!(not!isAggregate)
            .map!(cursor => cursor.spelling)
            .filter!(spelling => spelling in apiNotes.contextsWithConstructors)
            .each!(spelling => declarationsNeedingWrapping.put(spelling));
    }
}
