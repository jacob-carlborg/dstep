/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 30, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Type;

import clang.c.Index;
import clang.Cursor;
import clang.Type;

import dstep.translator.Context;
import dstep.translator.IncludeHandler;
import dstep.translator.Translator;
import dstep.translator.Output;

import std.conv;

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
        if (type.kind == CXType_BlockPointer || type.isFunctionPointerType)
            result = translateFunctionPointerType(context, cursor, type.pointee.func);

        else if (type.isFunctionType)
            result = translateFunctionPointerType(context, cursor, type.canonical.func);

        else if (type.kind == CXType_ObjCObjectPointer && !type.isObjCBuiltinType)
            result = translateObjCObjectPointerType(context, cursor, type);

        else if (type.isWideCharType)
            result = "wchar";

        else if (type.isObjCIdType)
            result = rewriteIdToObjcObject ? "ObjcObject" : "id";

        else
            switch (type.kind)
            {
                case CXType_Pointer:
                    return translatePointer(context, cursor, type, rewriteIdToObjcObject, applyConst);

                case CXType_Typedef:
                    result = translateTypedef(context, type); break;

                case CXType_Record:
                case CXType_Enum:
                case CXType_ObjCInterface:
                    result = type.spelling;

                    if (result.length == 0)
                        result = context.getAnonymousName(type.declaration);

                    handleInclude(context, type);
                break;

                case CXType_ConstantArray:
                case CXType_IncompleteArray:
                    result = translateArray(
                        context,
                        cursor,
                        type,
                        rewriteIdToObjcObject,
                        type.array.numDimensions - 1);
                    break;

                case CXType_Unexposed:
                    result = translateUnexposed(
                        context,
                        type,
                        rewriteIdToObjcObject);
                    break;

                default: result = translateType(context, type.kind, rewriteIdToObjcObject);
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
    else
    {
        auto kind = type.canonical.kind;

        if (kind == CXTypeKind.CXType_Int)
            return "dchar";
        else if (kind == CXTypeKind.CXType_Short)
            return "wchar";
        else
            return null;
    }
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
    assert(type.kind == CXTypeKind.CXType_Unexposed);
}
body
{
    auto declaration = type.declaration;

    if (declaration.isValid)
        return translateType(context, declaration, rewriteIdToObjcObject);
    else
        return translateType(context, type.kind, rewriteIdToObjcObject);
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
    assert(type.kind == CXTypeKind.CXType_ConstantArray
        || type.kind == CXTypeKind.CXType_IncompleteArray);
}
body
{
    import std.format : format;

    auto array = type.array;
    string elementType;

    if (array.elementType.kind == CXTypeKind.CXType_ConstantArray)
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
            CXCursorKind.CXCursor_IntegerLiteral,
            CXCursorKind.CXCursor_DeclRefExpr);

        if (dimension < children.length)
        {
            if (children[dimension].kind == CXCursorKind.CXCursor_IntegerLiteral)
            {
                auto expansions = context.macroIndex.queryExpansion(children[dimension]);

                if (expansions.length == 1)
                    return format("%s[%s]", elementType, expansions[0].spelling);
            }
            else if (children[dimension].kind == CXCursorKind.CXCursor_DeclRefExpr)
            {
                return format("%s[%s]", elementType, children[dimension].spelling);
            }
        }

        if (cursor.semanticParent.kind == CXCursorKind.CXCursor_FunctionDecl && dimension == 0)
            return format("ref %s[%s]", elementType, array.size);
        else
            return format("%s[%s]", elementType, array.size);
    }
    else if (cursor.semanticParent.kind == CXCursorKind.CXCursor_FunctionDecl)
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
    assert(type.kind == CXTypeKind.CXType_Pointer);
}
body
{
    static bool valueTypeIsConst (Type type)
    {
        auto pointee = type.pointee;

        while (pointee.kind == CXTypeKind.CXType_Pointer)
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
        if (child.kind == CXCursorKind.CXCursor_ParmDecl)
            result.put(translateParameter(context, child));
    }

    return result.data;
}

string translateFunctionPointerType (Context context, Cursor cursor, FuncType func)
{
    auto params = translateParameters(context, cursor, func);
    auto result = translateType(context, cursor, func.resultType);

    Output output = new Output();
    translateFunction(output, result, "function", params, func.isVariadic);
    return output.data();
}

string translateObjCObjectPointerType (Context context, Cursor cursor, Type type)
in
{
    assert(type.kind == CXTypeKind.CXType_ObjCObjectPointer && !type.isObjCBuiltinType);
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
            case CXType_Invalid: return "<unimplemented>";
            case CXType_Unexposed: return "<unimplemented>";
            case CXType_Void: return "void";
            case CXType_Bool: return "bool";
            case CXType_Char_U: return "<unimplemented>";
            case CXType_UChar: return "ubyte";
            case CXType_Char16: return "wchar";
            case CXType_Char32: return "dchar";
            case CXType_UShort: return "ushort";
            case CXType_UInt: return "uint";

            case CXType_ULong:
                context.includeHandler.addCompatible();
                return "c_ulong";

            case CXType_ULongLong: return "ulong";
            case CXType_UInt128: return "<unimplemented>";
            case CXType_Char_S: return "char";
            case CXType_SChar: return "byte";
            case CXType_WChar: return "wchar";
            case CXType_Short: return "short";
            case CXType_Int: return "int";

            case CXType_Long:
                context.includeHandler.addCompatible();
                return "c_long";

            case CXType_LongLong: return "long";
            case CXType_Int128: return "<unimplemented>";
            case CXType_Float: return "float";
            case CXType_Double: return "double";
            case CXType_LongDouble: return "real";
            case CXType_NullPtr: return "null";
            case CXType_Overload: return "<unimplemented>";
            case CXType_Dependent: return "<unimplemented>";
            case CXType_ObjCId: return rewriteIdToObjcObject ? "ObjcObject" : "id";
            case CXType_ObjCClass: return "Class";
            case CXType_ObjCSel: return "SEL";

            case CXType_Complex:
            case CXType_Pointer:
            case CXType_BlockPointer:
            case CXType_LValueReference:
            case CXType_RValueReference:
            case CXType_Record:
            case CXType_Enum:
            case CXType_Typedef:
            case CXType_FunctionNoProto:
            case CXType_FunctionProto:
            case CXType_Vector:
            case CXType_IncompleteArray:
            case CXType_VariableArray:
            case CXType_DependentSizedArray:
            case CXType_MemberPointer:
                return "<unimplemented>";

            default: assert(0, "Unhandled type kind " ~ to!string(kind));
        }
}
