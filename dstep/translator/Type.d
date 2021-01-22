/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 30, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Type;

import std.conv;
import std.string;
import std.range;
import std.typecons: Nullable;

import clang.c.Index;
import clang.Cursor;
import clang.Type;
import clang.Token: Token;

import dstep.translator.Context;
import dstep.translator.IncludeHandler;
import dstep.translator.Translator;
import dstep.translator.Output;

SourceNode translateType (Context context, Cursor cursor, bool rewriteIdToObjcObject = true, bool applyConst = true)
{
    return translateType(context, cursor, cursor.type, rewriteIdToObjcObject, applyConst);
}

SourceNode translateType (Context context, Cursor cursor, Type type, bool rewriteIdToObjcObject = true, bool applyConst = true)
in
{
    assert(type.isValid);
}
do
{
    SourceNode result;

    with (CXTypeKind)
    {
        if (type.kind == blockPointer || type.isFunctionPointerType)
            result = translateFunctionPointerType(context, cursor, type.pointee.func);

        else if (type.isFunctionType)
            result = translateFunctionPointerType(context, cursor, type.canonical.func);

        else if (type.kind == objCObjectPointer && !type.isObjCBuiltinType)
            result = translateObjCObjectPointerType(context, cursor, type);

        else if (type.isWideCharType)
            result = makeSourceNode("wchar");

        else if (type.isObjCIdType)
            result = makeSourceNode(rewriteIdToObjcObject ? "ObjcObject" : "id");

        else
            switch (type.kind)
            {
                case pointer:
                    return translatePointer(context, cursor, type, rewriteIdToObjcObject, applyConst);

                case typedef_:
                    result = translateTypedef(context, type).makeSourceNode();
                    break;

                case record:
                case enum_:
                    result = makeSourceNode(context.translateTagSpelling(type.declaration));
                    handleInclude(context, type);
                    break;

                case objCInterface:
                    if (type.spelling.empty)
                        result = makeSourceNode(context.getAnonymousName(type.declaration));
                    else
                        result = makeSourceNode(type.spelling);

                    handleInclude(context, type);
                    break;

                case constantArray:
                case incompleteArray:
                    result = translateArray(
                        context,
                        cursor,
                        type,
                        rewriteIdToObjcObject,
                        type.array.numDimensions - 1);
                    break;

                case unexposed:
                    result = translateUnexposed(
                        context,
                        type,
                        rewriteIdToObjcObject);
                    break;

                case elaborated:
                    result = translateElaborated(
                        context,
                        cursor,
                        type,
                        rewriteIdToObjcObject);
                    break;

                case complex:
                    result = translateComplex(type).makeSourceNode();
                    break;

                default:
                    result = translateType(
                        context,
                        type.kind,
                        rewriteIdToObjcObject)
                        .makeSourceNode();
            }
    }

    version (D1)
    {
        // ignore const
    }
    else
    {
        if (applyConst && type.isConst)
            result = result.prefixWith("const ");
    }

    return result;
}

SourceNode translateElaborated (Context context, Cursor cursor, Type type, bool rewriteIdToObjcObject = true, bool applyConst = true)
{
    auto named = type.named();

    if (named.kind == CXTypeKind.record || named.kind == CXTypeKind.enum_)
    {
        auto result = context.translateTagSpelling(named.declaration);
        handleInclude(context, type);
        return result.makeSourceNode();
    }
    else
    {
        return translateType(
            context,
            cursor,
            type.named,
            rewriteIdToObjcObject);
    }
}

string translateSelector (string str, bool fullName = false, bool translateIdentifier = true)
{
    import std.array : replace;
    import std.string : indexOf;

    if (fullName)
        str = str.replace(":", "_");

    else
    {
        auto i = str.indexOf(":");

        if (i > -1)
            str = str[0 .. i];
    }

    return translateIdentifier ? .translateIdentifier(str) : str;
}

package string reduceAlias(Type type)
{
    import std.typecons;

    enum aliasMapping = [
        tuple("byte", CXTypeKind.uChar): "ubyte",
        tuple("BOOL", CXTypeKind.bool_): "bool",
        tuple("BOOL", CXTypeKind.sChar): "bool",

        tuple("int8_t", CXTypeKind.sChar): "byte",
        tuple("int16_t", CXTypeKind.short_): "short",
        tuple("int32_t", CXTypeKind.int_): "int",
        tuple("int64_t", CXTypeKind.longLong): "long",
        tuple("uint8_t", CXTypeKind.uChar): "ubyte",
        tuple("uint16_t", CXTypeKind.uShort): "ushort",
        tuple("uint32_t", CXTypeKind.uInt): "uint",
        tuple("uint64_t", CXTypeKind.uLongLong): "ulong",

        tuple("__s8", CXTypeKind.sChar): "byte",
        tuple("__s16", CXTypeKind.short_): "short",
        tuple("__s32", CXTypeKind.int_): "int",
        tuple("__s64", CXTypeKind.longLong): "long",
        tuple("__u8", CXTypeKind.uChar): "ubyte",
        tuple("__u16", CXTypeKind.uShort): "ushort",
        tuple("__u32", CXTypeKind.uInt): "uint",
        tuple("__u64", CXTypeKind.uLongLong): "ulong",

        tuple("s8", CXTypeKind.sChar): "byte",
        tuple("s16", CXTypeKind.short_): "short",
        tuple("s32", CXTypeKind.int_): "int",
        tuple("s64", CXTypeKind.longLong): "long",
        tuple("u8", CXTypeKind.uChar): "ubyte",
        tuple("u16", CXTypeKind.uShort): "ushort",
        tuple("u32", CXTypeKind.uInt): "uint",
        tuple("u64", CXTypeKind.uLongLong): "ulong"
    ];

    auto canonical = type.canonical;
    auto kind = canonical.kind;

    if (kind == CXTypeKind.long_ && canonical.sizeOf == 8)
        kind = CXTypeKind.longLong;
    else if (kind == CXTypeKind.uLong && canonical.sizeOf == 8)
        kind = CXTypeKind.uLongLong;

    if (auto alias_ = tuple(type.spelling, kind) in aliasMapping)
        return *alias_;
    else
        return null;
}

package bool isAliasReducible(Type type)
{
    return reduceAlias(type) != null;
}

private:

string translateWCharT(Context context, Type type)
{
    if (context.options.portableWCharT)
    {
        context.includeHandler.addImport("core.stdc.stddef");
        return "wchar_t";
    }
    else if (type.canonical.kind.isIntegral)
    {
        auto sizeOf = type.canonical.sizeOf;

        if (sizeOf == 4)
            return "dchar";
        else if (sizeOf == 2)
            return "wchar";
    }

    return "<unimplemented>";
}

string translateTypedef(Context context, Type type)
{
    if (context.options.reduceAliases)
    {
        if (auto transl = reduceAlias(type))
            return transl;
    }

    auto spelling = type.spelling;

    with (CXTypeKind)
        switch (spelling)
        {
            case "size_t":
            case "ptrdiff_t":
            case "sizediff_t":
                return spelling;

            case "wchar_t":
                return translateWCharT(context, type);

            default: break;
        }


    handleInclude(context, type);

    if (isDKeyword(type.spelling))
    {
        return type.spelling != translateType(context, type.canonical.kind)
            ? renameDKeyword(type.spelling)
            : type.spelling;
    }
    else
    {
        return type.spelling;
    }
}

SourceNode translateUnexposed (Context context, Type type, bool rewriteIdToObjcObject)
in
{
    assert(type.kind == CXTypeKind.unexposed);
}
do
{
    auto declaration = type.declaration;

    if (declaration.isValid)
        return translateType(context, declaration, rewriteIdToObjcObject);
    else
        return translateType(context, type.kind, rewriteIdToObjcObject)
            .makeSourceNode();
}

string translateComplex (Type type)
{
    switch (type.element.kind)
    {
        case CXTypeKind.float_: return "cfloat";
        case CXTypeKind.double_: return "cdouble";
        case CXTypeKind.longDouble: return "creal";
        default: return "<unimplemented>";
    }
}

SourceNode translateArrayElement(
    Context context,
    Cursor cursor,
    ArrayType array,
    bool rewriteIdToObjcObject)
{
    import std.format : format;

    bool isConst = array.elementType.isConst;

    auto type = translateType(
        context,
        cursor,
        array.elementType,
        rewriteIdToObjcObject,
        !isConst);

    if (isConst)
        return type.wrapWith("const(", ")");
    else
        return type;
}

SourceNode translateArray (
    Context context,
    Cursor cursor,
    Type type,
    bool rewriteIdToObjcObject,
    size_t dimension = 0)
in
{
    assert(type.kind == CXTypeKind.constantArray
        || type.kind == CXTypeKind.incompleteArray);
}
do
{
    import std.format : format;

    auto array = type.array;
    SourceNode elementType;

    if (array.elementType.kind == CXTypeKind.constantArray)
    {
        elementType = translateArray(
            context,
            cursor,
            array.elementType,
            rewriteIdToObjcObject,
            dimension == 0 ? 0 : dimension - 1);
    }
    else
    {
        elementType = translateArrayElement(
            context,
            cursor,
            array,
            rewriteIdToObjcObject);
    }

    if (array.size >= 0)
    {
        auto children = cursor.filterChildren(
            CXCursorKind.integerLiteral,
            CXCursorKind.declRefExpr);

        auto maybeRef(T)(auto ref T value) {
            return cursor.semanticParent.kind == CXCursorKind.functionDecl && dimension == 0
                ? elementType.wrapWith("ref ", format("[%s]", value))
                : elementType.suffixWith(format("[%s]", value));
        }

        if (dimension < children.length)
        {
            if (children[dimension].kind == CXCursorKind.integerLiteral)
            {
                auto token = tokenInsideSquareBrackets(cursor, dimension);

                if (!token.isNull)
                {
                    return maybeRef(token.get.spelling);
                }

                auto expansions = context.macroIndex.queryExpansion(children[dimension]);

                if (expansions.length == 1)
                    return elementType.suffixWith(format("[%s]", expansions[0].spelling));
            }
            else if (children[dimension].kind == CXCursorKind.declRefExpr)
            {
                return elementType.suffixWith(format("[%s]", children[dimension].spelling));
            }
        }

        return maybeRef(array.size);
    }
    else if (cursor.semanticParent.kind == CXCursorKind.functionDecl)
    {
        return elementType.suffixWith("*");
    }
    else
    {
        // FIXME: Find a way to translate references to static external arrays with unknown size.

        // extern static arrays (which are normally present in bindings)
        // have same ABI as extern dynamic arrays, size is only checked
        // against declaration in header. As it is not possible in D
        // to define static array with ABI of dynamic one, only way is to
        // abandon the size information
        return elementType.suffixWith("[]");
    }
}

// find the token for a (possibly multidimensioned) array for a certain dimension,
// e.g. int foo[1][2][3] will find the "3" for dimension 0 due to the differences
// in array declarations between D and C
private Nullable!Token tokenInsideSquareBrackets(Cursor cursor, in size_t dimension)
{
    import std.algorithm: find;
    import std.range: retro;
    import clang.Token: TokenKind;

    auto fromNextBracket(R)(R tokens)
    {
        return tokens.find!(a => a.kind == TokenKind.punctuation && a.spelling == "]");
    }

    auto tokens = cursor.tokens.retro.find!(_ => true);

    // dimension + 1 since dimension is 0-indexed and we need to find at least one
    foreach(_; 0 .. dimension + 1)
    {
        tokens = fromNextBracket(tokens);
        if (tokens.empty) return typeof(return).init;
        tokens.popFront;
    }

    return tokens.empty
        ? typeof(return).init
        : typeof(return)(tokens.front);
}

SourceNode translatePointer (
    Context context,
    Cursor cursor,
    Type type,
    bool rewriteIdToObjcObject,
    bool applyConst)
in
{
    assert(type.kind == CXTypeKind.pointer);
}
do
{
    static bool valueTypeIsConst (Type type)
    {
        auto pointee = type.pointee;

        while (pointee.kind == CXTypeKind.pointer)
            pointee = pointee.pointee;

        return pointee.isConst;
    }

    auto result = translateType(context, cursor, type.pointee, rewriteIdToObjcObject, false);

    version (D1)
    {
        result = result ~ '*';
    }
    else
    {
        if (applyConst && valueTypeIsConst(type))
        {
            if (type.isConst)
                result = result.wrapWith("const ", "*");
            else
                result = result.wrapWith("const(", ")*");
        }
        else
            result = result.suffixWith("*");
    }

    return result;
}

Parameter translateParameter (Context context, Cursor parameter)
{
    Parameter result;

    result.type = translateType(context, parameter);
    result.name = parameter.spelling;
    result.isConst = false;

    return result;
}

Parameter[] translateParameters (Context context, Cursor cursor, FuncType func)
{
    import std.array : Appender;

    auto result = Appender!(Parameter[])();
    auto arguments = func.arguments;

    foreach (child; cursor.all)
    {
        if (child.kind == CXCursorKind.parmDecl)
            result.put(translateParameter(context, child));
    }

    return result.data;
}

SourceNode translateFunctionPointerType (Context context, Cursor cursor, FuncType func)
{
    auto params = translateParameters(context, cursor, func);
    auto result = translateType(context, cursor, func.resultType);
    auto spacer = context.options.spaceAfterFunctionName ? " " : "";
    auto multiline = cursor.extent.isMultiline &&
        !context.options.singleLineFunctionSignatures;

    return translateFunction(
        result,
        "function",
        params,
        func.isVariadic,
        "",
        spacer,
        multiline);
}

SourceNode translateObjCObjectPointerType (Context context, Cursor cursor, Type type)
in
{
    assert(type.kind == CXTypeKind.objCObjectPointer && !type.isObjCBuiltinType);
}
do
{
    auto pointee = type.pointee;

    if (pointee.spelling == "Protocol")
        return "Protocol*".makeSourceNode();

    else
        return translateType(context, cursor, pointee);
}

string translateType (Context context, CXTypeKind kind, bool rewriteIdToObjcObject = true)
{
    import std.conv;

    with (CXTypeKind)
        switch (kind)
        {
            case invalid: return "<unimplemented>";
            case unexposed: return "<unimplemented>";
            case void_: return "void";
            case bool_: return "bool";
            case charU: return "<unimplemented>";
            case uChar: return "ubyte";
            case char16: return "wchar";
            case char32: return "dchar";
            case uShort: return "ushort";
            case uInt: return "uint";

            case uLong:
                context.includeHandler.addCompatible();
                return "c_ulong";

            case uLongLong: return "ulong";
            case uInt128: return "<unimplemented>";
            case charS: return "char";
            case sChar: return "byte";
            case wChar: return "wchar";
            case short_: return "short";
            case int_: return "int";

            case long_:
                context.includeHandler.addCompatible();
                return "c_long";

            case longLong: return "long";
            case int128: return "<unimplemented>";
            case float_: return "float";
            case double_: return "double";
            case longDouble: return "real";
            case nullPtr: return "null";
            case overload: return "<unimplemented>";
            case dependent: return "<unimplemented>";
            case objCId: return rewriteIdToObjcObject ? "ObjcObject" : "id";
            case objCClass: return "Class";
            case objCSel: return "SEL";

            case pointer:
            case blockPointer:
            case lValueReference:
            case rValueReference:
            case record:
            case enum_:
            case typedef_:
            case functionNoProto:
            case functionProto:
            case vector:
            case incompleteArray:
            case variableArray:
            case dependentSizedArray:
            case memberPointer:
            case elaborated:
                return "<unimplemented>";

            default: assert(0, "Unhandled type kind " ~ to!string(kind));
        }
}
