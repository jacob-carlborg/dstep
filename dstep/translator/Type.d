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

import clang.c.Index;
import clang.Cursor;
import clang.Type;

import dstep.translator.Context;
import dstep.translator.IncludeHandler;
import dstep.translator.Translator;
import dstep.translator.Output;

string translateType (Context context, Cursor cursor, bool rewriteIdToObjcObject = true, bool applyConst = true)
{
    return translateType(context, cursor, cursor.type, rewriteIdToObjcObject, applyConst);
}

string translateType (Context context, Cursor cursor, Type type, bool rewriteIdToObjcObject = true, bool applyConst = true)
in
{
    assert(type.isValid);
}
body
{
    string result;

    with (CXTypeKind)
    {
        if (type.kind == blockPointer || type.isFunctionPointerType)
            result = translateFunctionPointerType(context, cursor, type.pointee.func);

        else if (type.isFunctionType)
            result = translateFunctionPointerType(context, cursor, type.canonical.func);

        else if (type.kind == objCObjectPointer && !type.isObjCBuiltinType)
            result = translateObjCObjectPointerType(context, cursor, type);

        else if (type.isWideCharType)
            result = "wchar";

        else if (type.isObjCIdType)
            result = rewriteIdToObjcObject ? "ObjcObject" : "id";

        else
            switch (type.kind)
            {
                case pointer:
                    return translatePointer(context, cursor, type, rewriteIdToObjcObject, applyConst);

                case typedef_:
                    result = translateTypedef(context, type); break;

                case record:
                case enum_:
                    result = context.translateTagSpelling(type.declaration);
                    handleInclude(context, type);
                    break;

                case objCInterface:
                    result = type.spelling;

                    if (result.empty)
                        result = context.getAnonymousName(type.declaration);

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
                    result = translateComplex(type);
                    break;

                default:
                    result = translateType(context, type.kind,
                                           rewriteIdToObjcObject);
            }
    }

    version (D1)
    {
        // ignore const
    }
    else
    {
        if (applyConst && type.isConst)
            result = "const " ~ result;
    }

    return result;
}

string translateElaborated (Context context, Cursor cursor, Type type, bool rewriteIdToObjcObject = true, bool applyConst = true)
{
    auto named = type.named();

    if (named.kind == CXTypeKind.record || named.kind == CXTypeKind.enum_)
    {
        auto result = context.translateTagSpelling(named.declaration);
        handleInclude(context, type);
        return result;
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
    auto spelling = type.spelling;

    switch (type.spelling)
    {
        case "BOOL": return "bool";
        case "int8_t": return "byte";
        case "int16_t": return "short";
        case "int32_t": return "int";
        case "int64_t": return "long";
        case "uint8_t": return "ubyte";
        case "uint16_t": return "ushort";
        case "uint32_t": return "uint";
        case "uint64_t": return "ulong";

        case "__s8": return "byte";
        case "__s16": return "short";
        case "__s32": return "int";
        case "__s64": return "long";
        case "__u8": return "ubyte";
        case "__u16": return "ushort";
        case "__u32": return "uint";
        case "__u64": return "ulong";

        case "s8": return "byte";
        case "s16": return "short";
        case "s32": return "int";
        case "s64": return "long";
        case "u8": return "ubyte";
        case "u16": return "ushort";
        case "u32": return "uint";
        case "u64": return "ulong";

        default: return null;
    }
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
    return type.spelling;
}

string translateUnexposed (Context context, Type type, bool rewriteIdToObjcObject)
in
{
    assert(type.kind == CXTypeKind.unexposed);
}
body
{
    auto declaration = type.declaration;

    if (declaration.isValid)
        return translateType(context, declaration, rewriteIdToObjcObject);
    else
        return translateType(context, type.kind, rewriteIdToObjcObject);
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

string translateArrayElement(
    Context context,
    Cursor cursor,
    ArrayType array,
    bool rewriteIdToObjcObject)
{
    import std.format : format;

    bool isConst = array.elementType.isConst;

    auto spelling = translateType(
        context,
        cursor,
        array.elementType,
        rewriteIdToObjcObject,
        !isConst);

    if (isConst)
        return format("const(%s)", spelling);
    else
        return spelling;
}

string translateArray (
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
body
{
    import std.format : format;

    auto array = type.array;
    string elementType;

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

        if (dimension < children.length)
        {
            if (children[dimension].kind == CXCursorKind.integerLiteral)
            {
                auto expansions = context.macroIndex.queryExpansion(children[dimension]);

                if (expansions.length == 1)
                    return format("%s[%s]", elementType, expansions[0].spelling);
            }
            else if (children[dimension].kind == CXCursorKind.declRefExpr)
            {
                return format("%s[%s]", elementType, children[dimension].spelling);
            }
        }

        if (cursor.semanticParent.kind == CXCursorKind.functionDecl && dimension == 0)
            return format("ref %s[%s]", elementType, array.size);
        else
            return format("%s[%s]", elementType, array.size);
    }
    else if (cursor.semanticParent.kind == CXCursorKind.functionDecl)
    {
        return format("%s*", elementType);
    }
    else
    {
        // FIXME: Find a way to translate references to static external arrays with unknown size.

        // extern static arrays (which are normally present in bindings)
        // have same ABI as extern dynamic arrays, size is only checked
        // against declaration in header. As it is not possible in D
        // to define static array with ABI of dynamic one, only way is to
        // abandon the size information
        return format("%s[]", elementType);
    }
}

string translatePointer (
    Context context,
    Cursor cursor,
    Type type,
    bool rewriteIdToObjcObject,
    bool applyConst)
in
{
    assert(type.kind == CXTypeKind.pointer);
}
body
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
                result = "const " ~ result ~ '*';
            else
                result = "const(" ~ result ~ ")*";
        }
        else
            result = result ~ '*';
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

string translateFunctionPointerType (Context context, Cursor cursor, FuncType func)
{
    auto params = translateParameters(context, cursor, func);
    auto result = translateType(context, cursor, func.resultType);

    Output output = new Output();
    auto spacer = context.options.spaceAfterFunctionName ? " " : "";
    translateFunction(output, result, "function",
                      params, func.isVariadic, "", spacer);

    return output.data();
}

string translateObjCObjectPointerType (Context context, Cursor cursor, Type type)
in
{
    assert(type.kind == CXTypeKind.objCObjectPointer && !type.isObjCBuiltinType);
}
body
{
    auto pointee = type.pointee;

    if (pointee.spelling == "Protocol")
        return "Protocol*";

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
