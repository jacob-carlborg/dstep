/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Translator;

import std.file;
import std.array;

import clang.c.Index;
import clang.Cursor;
import clang.File;
import clang.Index;
import clang.TranslationUnit;
import clang.Type;
import clang.Util;

import dstep.core.Exceptions;
import dstep.Configuration;

import dstep.translator.Context;
import dstep.translator.Declaration;
import dstep.translator.Enum;
import dstep.translator.IncludeHandler;
import dstep.translator.objc.Category;
import dstep.translator.objc.ObjcInterface;
import dstep.translator.Options;
import dstep.translator.Output;
import dstep.translator.MacroDefinition;
import dstep.translator.Record;
import dstep.translator.Type;
import dstep.translator.TypeInference;

public import dstep.translator.Options;

class TranslationException : DStepException
{
    this (string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}

class Translator
{
    private
    {
        TranslationUnit translationUnit;

        string outputFile;
        string inputFilename;
        File inputFile;
        Language language;
        string[string] deferredDeclarations;
    }

    TypedMacroDefinition[string] typedMacroDefinitions;
    Context context;

    this (TranslationUnit translationUnit, Options options = Options.init)
    {
        this.inputFilename = translationUnit.spelling;
        this.translationUnit = translationUnit;
        outputFile = options.outputFile;
        language = options.language;

        inputFile = translationUnit.file(inputFilename);
        context = new Context(translationUnit, options, this);
    }

    void translate ()
    {
        write(outputFile, translateToString());
    }

    Output translateCursors()
    {
        Output result = new Output(context.commentIndex);
        typedMacroDefinitions = inferMacroSignatures(context);

        bool first = true;

        foreach (cursor, parent; translationUnit.cursor.allInOrder)
        {
            if (!skipDeclaration(cursor))
            {
                if (first)
                {
                    if (result.flushHeaderComment())
                        result.separator();

                    externDeclaration(result);
                    first = false;
                }

                translateInGlobalScope(result, cursor, parent);
            }
        }

        if (context.commentIndex)
            result.flushLocation(context.commentIndex.queryLastLocation());

        foreach (value; deferredDeclarations.values)
            result.singleLine(value);

        result.finalize();

        return result;
    }

    string translateToString()
    {
        import std.algorithm.mutation : strip;

        Output main = translateCursors();
        Output head = new Output();

        moduleDeclaration(head);
        context.includeHandler.toImports(head);

        return main.header ~ head.data ~ main.content;
    }

    void translateInGlobalScope(
        Output output,
        Cursor cursor,
        Cursor parent = Cursor.empty)
    {
        translate(output, cursor, parent);

        if (!context.globalScope.empty)
        {
            output.separator();
            output.output(context.globalScope);
            output.separator();
            context.globalScope.reset();
        }
    }

    void translate (
        Output output,
        Cursor cursor,
        Cursor parent = Cursor.empty)
    {
        with (CXCursorKind)
        {
            switch (cursor.kind)
            {
                case objCInterfaceDecl:
                    output.flushLocation(cursor.extent, false);
                    translateObjCInterfaceDecl(output, cursor, parent);
                    break;

                case objCProtocolDecl:
                    output.flushLocation(cursor.extent, false);
                    translateObjCProtocolDecl(output, cursor, parent);
                    break;

                case objCCategoryDecl:
                    output.flushLocation(cursor.extent, false);
                    translateObjCCategoryDecl(output, cursor, parent);
                    break;

                case varDecl:
                    output.flushLocation(cursor.extent);
                    translateVarDecl(output, cursor, parent);
                    break;

                case functionDecl:
                    translateFunctionDecl(output, cursor, parent);
                    break;

                case typedefDecl:
                    translateTypedefDecl(output, cursor);
                    break;

                case structDecl:
                    translateRecord(output, context, cursor);
                    break;

                case enumDecl:
                    translateEnum(output, context, cursor);
                    break;

                case unionDecl:
                    translateRecord(output, context, cursor);
                    break;

                case macroDefinition:
                    output.flushLocation(cursor.extent);
                    translateMacroDefinition(output, cursor, parent);
                    break;

                case macroExpansion:
                    output.flushLocation(cursor.extent);
                    break;

                default:
                    break;
            }
        }
    }

    void translateObjCInterfaceDecl(Output output, Cursor cursor, Cursor parent)
    {
        (new ObjcInterface!(ClassData)(cursor, parent, this)).translate(output);
    }

    void translateObjCProtocolDecl(Output output, Cursor cursor, Cursor parent)
    {
        (new ObjcInterface!(InterfaceData)(cursor, parent, this)).translate(output);
    }

    void translateObjCCategoryDecl(Output output, Cursor cursor, Cursor parent)
    {
        (new Category(cursor, parent, this)).translate(output);
    }

    void translateVarDecl(Output output, Cursor cursor, Cursor parent)
    {
        version (D1)
            string storageClass = "extern ";
        else
            string storageClass = "extern __gshared ";

        variable(output, cursor, storageClass);
    }

    void translateFunctionDecl(Output output, Cursor cursor, Cursor parent)
    {
        output.flushLocation(cursor.extent);

        immutable auto name = translateIdentifier(cursor.spelling);
        output.adaptiveSourceNode(translateFunction(context, cursor.func, name));
        output.append(";");
    }

    void declareRecordForTypedef(Output output, Cursor typedef_)
    {
        assert(typedef_.kind == CXCursorKind.typedefDecl);

        auto underlying = typedef_.underlyingCursor();

        if (underlying.isEmpty)
            return;

        if (underlying.isEmpty ||
            underlying.kind != CXCursorKind.structDecl &&
            underlying.kind != CXCursorKind.unionDecl)
            return;

        if (context.alreadyDefined(underlying.canonical))
            return;

        bool skipdef = shouldSkipRecordDefinition(context, underlying);

        if (underlying.definition.isEmpty || skipdef)
            translateRecordDecl(output, context, underlying);
    }

    bool shouldSkipAlias(Cursor typedef_)
    {
        assert(typedef_.kind == CXCursorKind.typedefDecl);
        return context.options.reduceAliases && typedef_.type.isAliasReducible;
    }

    void translateTypedefDecl(Output output, Cursor typedef_)
    {
        assert(typedef_.kind == CXCursorKind.typedefDecl);

        output.flushLocation(typedef_.extent);

        auto underlying = typedef_.underlyingCursor;

        if (!context.shouldSkipRecord(underlying) && !shouldSkipAlias(typedef_))
        {
            declareRecordForTypedef(output, typedef_);

            if (underlying.isEmpty ||
                (underlying.spelling != typedef_.spelling &&
                underlying.spelling != ""))
            {
                auto canonical = typedef_.type.canonical;
                auto spelling = typedef_.spelling;
                auto type = translateType(context, typedef_, canonical);

                version (D1)
                {
                    output.adaptiveSourceNode(
                        type.wrapWith("alias ", " " ~ spelling ~ ";"));
                }
                else
                {
                    output.adaptiveSourceNode(
                        type.wrapWith("alias " ~ spelling ~ " = ", ";"));
                }

                context.markAsDefined(typedef_);
            }
        }
    }

    void translateMacroDefinition(Output output, Cursor cursor, Cursor parent)
    {
        if (context.options.translateMacros)
        {
            if (auto definition = cursor.spelling in typedMacroDefinitions)
            {
                dstep.translator.MacroDefinition
                    .translateMacroDefinition(output, context, *definition);
            }
        }
    }

    void variable (Output output, Cursor cursor, string prefix = "")
    {
        translateVariable(output, context, cursor, prefix);
    }

private:

    bool skipDeclaration (Cursor cursor)
    {
        return (inputFilename != "" &&
            inputFile != cursor.location.spelling.file)
            || context.options.skipSymbols.contains(cursor.spelling)
            || cursor.isPredefined;
    }

    void moduleDeclaration (Output output)
    {
        if (context.options.packageName != "")
        {
            output.singleLine("module %s;", fullModuleName(
                context.options.packageName,
                context.options.outputFile,
                context.options.normalizeModules));

            output.separator();
        }
    }

    void externDeclaration (Output output)
    {
        final switch (language)
        {
            case Language.c:
                output.singleLine("extern (C):");
                break;

            case Language.objC:
                output.singleLine("extern (Objective-C):");
                break;
        }

        foreach (attribute; context.options.globalAttributes)
            output.singleLine("%s:", attribute);

        output.separator();
    }
}

SourceNode translateFunction (
    Context context,
    FunctionCursor func,
    string name,
    bool isStatic = false)
{
    bool isVariadic(Context context, size_t numParams, FunctionCursor func)
    {
        if (func.isVariadic)
        {
            if (context.options.zeroParamIsVararg)
                return true;
            else if (numParams == 0)
                return false;
            else
                return true;
        }

        return false;
    }

    Parameter[] params;

    if (func.type.isValid) // This will be invalid for Objective-C methods
        params.reserve(func.type.func.arguments.length);

    foreach (param ; func.parameters)
    {
        auto type = translateType(context, param);
        params ~= Parameter(type, param.spelling);
    }

    auto resultType = translateType(context, func, func.resultType);
    auto multiline = func.extent.isMultiline &&
        !context.options.singleLineFunctionSignatures;
    auto spacer = context.options.spaceAfterFunctionName ? " " : "";

    return translateFunction(
        resultType,
        name,
        params,
        isVariadic(context, params.length, func),
        isStatic ? "static " : "",
        spacer,
        multiline);
}

package struct Parameter
{
    SourceNode type;
    string name;
    bool isConst;
}

package SourceNode translateFunction (
    SourceNode resultType,
    string name,
    Parameter[] parameters,
    bool variadic,
    string prefix = "",
    string spacer = " ",
    bool multiline = false)
{
    import std.format : format;

    string[] params;
    params.reserve(parameters.length);

    foreach (param ; parameters)
    {
        string p;

        version(D1)
        {
            p ~= param.type;
        }
        else
        {
            if (param.isConst)
                p ~= "const(";

            p ~= param.type.makeString();

            if (param.isConst)
                p ~= ')';
        }

        if (param.name.length)
            p ~= " " ~ translateIdentifier(param.name);

        params ~= p;
    }

    if (variadic)
        params ~= "...";

    auto result = makeSourceNode(
        format("%s%s %s%s(", prefix, resultType.makeString(), name, spacer),
        params,
        ",",
        ")");

    return multiline ? result : result.flatten();
}

void translateVariable (Output output, Context context, Cursor cursor, string prefix = "")
{
    if (!context.alreadyDefined(cursor.canonical))
    {
        auto type = translateType(context, cursor, cursor.type);
        auto identifier = translateIdentifier(cursor.spelling);
        output.adaptiveSourceNode(type.wrapWith(prefix, " " ~ identifier ~ ";"));
        context.markAsDefined(cursor.canonical);
    }
}

string translateIdentifier (string str)
{
    return isDKeyword(str) ? str ~ '_' : str;
}

void handleInclude (Context context, Type type)
{
    import std.algorithm.searching;
    import std.path;

    if (type.kind == CXTypeKind.typedef_
        && type.spelling == "time_t"
        && type.declaration.path.asNormalizedPath.array.endsWith("sys\\types.h"))
        context.includeHandler.addInclude("time.h");
    else
        context.includeHandler.addInclude(type.declaration.path);

    context.includeHandler.resolveDependency(type.declaration);
}

bool isDKeyword (string str)
{
    switch (str)
    {
        case "abstract":
        case "alias":
        case "align":
        case "asm":
        case "assert":
        case "auto":

        case "body":
        case "bool":
        case "break":
        case "byte":

        case "case":
        case "cast":
        case "catch":
        case "cdouble":
        case "cent":
        case "cfloat":
        case "char":
        case "class":
        case "const":
        case "continue":
        case "creal":

        case "dchar":
        case "debug":
        case "default":
        case "delegate":
        case "delete":
        case "deprecated":
        case "do":
        case "double":

        case "else":
        case "enum":
        case "export":
        case "extern":

        case "false":
        case "final":
        case "finally":
        case "float":
        case "for":
        case "foreach":
        case "foreach_reverse":
        case "function":

        case "goto":

        case "idouble":
        case "if":
        case "ifloat":
        case "import":
        case "in":
        case "inout":
        case "int":
        case "interface":
        case "invariant":
        case "ireal":
        case "is":

        case "lazy":
        case "long":

        case "macro":
        case "mixin":
        case "module":

        case "new":
        case "nothrow":
        case "null":

        case "out":
        case "override":

        case "package":
        case "pragma":
        case "private":
        case "protected":
        case "public":
        case "pure":

        case "real":
        case "ref":
        case "return":

        case "scope":
        case "shared":
        case "short":
        case "static":
        case "struct":
        case "super":
        case "switch":
        case "synchronized":

        case "template":
        case "this":
        case "throw":
        case "true":
        case "try":
        case "typedef":
        case "typeid":
        case "typeof":

        case "ubyte":
        case "ucent":
        case "uint":
        case "ulong":
        case "union":
        case "unittest":
        case "ushort":

        case "version":
        case "void":
        case "volatile":

        case "wchar":
        case "while":
        case "with":

        case "__FILE__":
        case "__LINE__":
        case "__DATE__":
        case "__TIME__":
        case "__TIMESTAMP__":
        case "__VENDOR__":
        case "__VERSION__":
            return true;

        default: break;
    }

    if (true /*D2*/)
    {
        switch (str)
        {
            case "immutable":
            case "nothrow":
            case "pure":
            case "shared":

            case "__gshared":
            case "__thread":
            case "__traits":

            case "__EOF__":
                return true;

            default: return str.length && str[0] == '@';
        }
    }

    return false;
}
