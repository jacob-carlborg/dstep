/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Translator;

import std.algorithm;
import std.file;
import std.format;
import std.array;
import std.path;
import std.range;
import std.typecons;

import clang.c.Index;
import clang.Cursor;
import clang.File;
import clang.Index;
import clang.SourceRange;
import clang.TranslationUnit;
import clang.Type;
import clang.Util;

import dstep.core.Core;
import dstep.core.Exceptions;
import dstep.core.Optional;
import dstep.Configuration;

import dstep.translator.ApiNotes;
import dstep.translator.ApiNotesTranslator;
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
    ApiNotesTranslator apiNotesTranslator;

    private
    {
        TranslationUnit translationUnit;

        string outputFile;
        string inputFilename;
        File inputFile;
        Language language;
        string[string] deferredDeclarations;
        ApiNotes apiNotes;
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
        apiNotes = ApiNotes.parse(options.apiNotes);
        apiNotesTranslator = ApiNotesTranslator(context);
    }

    void translate ()
    {
        write(outputFile, translateToString());
        writeAnnotatedDeclarations();
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

    string[string] translateAnnotatedDeclarations()
    {
        synthesisAnnotatedDeclarations();

        const directory = dirName(outputFile);

        alias createOutput = ad => tuple(ad.declaration.get, new Output);
        alias writeToOutput = (declaration, output) => declaration.write(output);

        alias generateFilename = declaration =>
            buildPath(directory, declaration.name) ~ ".d";

        alias toFilename = (declaration, output ) =>
            tuple(generateFilename(declaration), output);

        return apiNotesTranslator
            .declarations
            .byValue
            .filter!(ad => ad.declaration.isPresent)
            .tee!(ad => ad.addMembersToDeclaration(), No.pipeOnPop)
            .map!createOutput
            .cache
            .tee!(t => writeToOutput(t.expand), No.pipeOnPop)
            .map!(t => toFilename(t.expand))
            .map!(t => tuple(t[0], t[1].data))
            .assocArray;
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
                    translateRecord(output, this, cursor, apiNotes);
                    break;

                case enumDecl:
                    translateEnum(output, context, cursor);
                    break;

                case unionDecl:
                    translateRecord(output, this, cursor, apiNotes);
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

        auto func = apiNotes.lookupFunction(cursor.spelling);
        const newSpelling = func.baseName.or(cursor.spelling);
        immutable auto name = translateIdentifier(newSpelling);
        const mangledName = cursor.mangling == name ? none!string : cursor.mangling.some;

        if (func.isInstanceMethod.or(false))
            func.each!(f => apiNotesTranslator.freeFunctionToInstanceMethod(cursor, name, f));

        else if (func.isConstructor.or(false))
            func.each!(f => apiNotesTranslator.freeFunctionToConstructor(cursor, f));

        else if (func.isStaticMethod.or(false))
            func.each!(f => apiNotesTranslator.freeFunctionToStaticMethod(cursor, name, f));

        else
        {
            auto function_ = Function(
                cursor: cursor.func,
                name: name,
                mangledName: mangledName
            );

            auto result = translateFunction(context, function_);
            output.adaptiveSourceNode(result);
            output.append(";");
        }
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

            auto typedefp = context.typedefParent(underlying);

            if (typedef_ != typedefp ||
                underlying.isEmpty ||
                (underlying.spelling != typedef_.spelling &&
                underlying.spelling != ""))
            {
                auto canonical = typedef_.type.canonical;

                auto type = translateType(context, typedef_, canonical);

                auto typeSpelling = type.makeString();

                // Do not alias itself
                if (typedef_.spelling != typeSpelling)
                {
                    auto spelling = translateIdentifier(typedef_.spelling);

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

    void writeAnnotatedDeclarations()
    {
        foreach (filename, data; translateAnnotatedDeclarations)
            write(filename, data);
    }

    void synthesisAnnotatedDeclarations()
    {
        auto decls = apiNotesTranslator
            .declarations
            .byValue
            .filter!(e => e.declaration.empty);

        foreach (ad; decls)
        {
            assert(ad.cursor.isPresent);
            auto cursor = ad.cursor.get;
            auto type = translateType(context, cursor, cursor.func.resultType);

            StructData.Body body = (output) {
                translateVariable(output, type,
                    identifier: "rawValue", prefix: "private ");
            };

            auto extent = SourceRange(clang_getNullRange());
            apiNotesTranslator.addAnnotatedDeclaration(
                new StructData(ad.name, "struct", extent, body)
            );
        }
    }
}

SourceNode translateFunction (
    Context context,
    Function func)
{
    bool isVariadic(Context context, size_t numParams, FunctionCursor cursor)
    {
        if (cursor.isVariadic)
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

    if (func.cursor.type.isValid) // This will be invalid for Objective-C methods
        params.reserve(func.cursor.type.func.arguments.length);

    foreach (param ; func.cursor.parameters)
    {
        auto type = translateType(context, param);
        params ~= Parameter(type, param.spelling);
    }

    const parameterStart = func.apiNotesFunction.isInstanceMethod.or(false) ? 1 : 0;
    params = params[parameterStart .. $];

    auto resultType = translateType(context, func.cursor, func.cursor.resultType);
    auto multiline = func.cursor.extent.isMultiline &&
        !context.options.singleLineFunctionSignatures;
    auto spacer = context.options.spaceAfterFunctionName ? " " : "";

    const mangling = func
        .mangledName
        .map!(name => format!`pragma(mangle, "%s")`(name))
        .or("");

    const prefixes = [
        func.isStatic ? "static" : "",
        mangling
    ].filter!(e => e.length > 0).array;

    const prefix = prefixes.join(" ");

    return translateFunction(
        resultType,
        func.name,
        params,
        isVariadic(context, params.length, func.cursor),
        prefix.length > 0 ? prefix ~ ' ' : prefix,
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
        translateVariable(output, type, cursor.spelling, prefix);
        context.markAsDefined(cursor.canonical);
    }
}

private void translateVariable(Output output, SourceNode typeSourceNode,
    string identifier, string prefix = "")
{
    auto newIdentifier = translateIdentifier(identifier);
    output.adaptiveSourceNode(typeSourceNode.wrapWith(prefix, " " ~ newIdentifier ~ ";"));
}

void handleInclude (Context context, Type type)
{
    import std.algorithm.searching;
    import std.path;

    if (!context.includeHandler.resolveDependency(type.declaration)) {
        context.includeHandler.addInclude(type.declaration.path);
    }
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

string renameDKeyword (string str)
{
    return str ~ '_';
}

string translateIdentifier (string str)
{
    return isDKeyword(str) ? renameDKeyword(str) : str;
}

struct Function
{
    FunctionCursor cursor;
    string name;
    Optional!string mangledName;
    bool isStatic;
    Optional!(dstep.translator.ApiNotes.Function) apiNotesFunction;
}
