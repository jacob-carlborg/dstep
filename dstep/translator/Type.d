/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 30, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Type;

import mambo.core.string;
import mambo.core.io;

import clang.c.index;
import clang.Type;

import dstep.translator.IncludeHandler;
import dstep.translator.Translator;
import dstep.translator.Output;

string translateType (Type type, bool rewriteIdToObjcObject = true, bool applyConst = true)
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
            result = translateFunctionPointerType(type);
            
        else if (type.kind == CXType_ObjCObjectPointer && !type.isObjCBuiltinType)
            result = translateObjCObjectPointerType(type);
            
        else if (type.isWideCharType)
            result = "wchar";
            
        else if (type.isObjCIdType)
            result = rewriteIdToObjcObject ? "ObjcObject" : "id";

        else
            switch (type.kind)
            {
                case CXType_Pointer: return translatePointer(type, rewriteIdToObjcObject, applyConst);
                case CXType_Typedef: result = translateTypedef(type); break;

                case CXType_Record:
                case CXType_Enum:
                case CXType_ObjCInterface:
                    result = type.spelling;

                    if (result.isEmpty)
                        result = getAnonymousName(type.declaration);

                    handleInclude(type);
                break;
                
                case CXType_ConstantArray: result = translateConstantArray(type, rewriteIdToObjcObject); break;
                case CXType_Unexposed: result = translateUnexposed(type, rewriteIdToObjcObject); break;

                default: result = translateType(type.kind, rewriteIdToObjcObject);
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

private:

string translateTypedef (Type type)
in
{
    assert(type.kind == CXTypeKind.CXType_Typedef);
}
body
{
    auto spelling = type.spelling;

    with (CXTypeKind)
        switch (spelling)
        {
            case "BOOL": return translateType(CXType_Bool);

            case "int64_t": return translateType(CXType_LongLong);
            case "int32_t": return translateType(CXType_Int);
            case "int16_t": return translateType(CXType_Short);
            case "int8_t": return "byte";

            case "uint64_t": return translateType(CXType_ULongLong);
            case "uint32_t": return translateType(CXType_UInt);
            case "uint16_t": return translateType(CXType_UShort);
            case "uint8_t": return translateType(CXType_UChar);

            case "size_t":
            case "ptrdiff_t":
            case "sizediff_t":
                return spelling;

            case "wchar_t":
                auto kind = type.canonicalType.kind;

                if (kind == CXType_Int)
                    return "dchar";

                else if (kind == CXType_Short)
                    return "wchar";

            default: break;
        }

    handleInclude(type);

    return spelling;
}

string translateUnexposed (Type type, bool rewriteIdToObjcObject)
in
{
    assert(type.kind == CXTypeKind.CXType_Unexposed);
}
body
{
    auto declaration = type.declaration;

    if (declaration.isValid)
        return translateType(declaration.type, rewriteIdToObjcObject);
        
    else
        return translateType(type.kind, rewriteIdToObjcObject);
}

string translateConstantArray (Type type, bool rewriteIdToObjcObject)
in
{
    assert(type.kind == CXTypeKind.CXType_ConstantArray);
}
body
{
    auto array = type.array;
    auto elementType = translateType(array.elementType, rewriteIdToObjcObject);
    
    return elementType ~ '[' ~ array.size.toString ~ ']';
}

string translatePointer (Type type, bool rewriteIdToObjcObject, bool applyConst)
in
{
    assert(type.kind == CXTypeKind.CXType_Pointer);
}
body
{
    static bool valueTypeIsConst (Type type)
    {
        auto pointee = type.pointeeType;

        while (pointee.kind == CXTypeKind.CXType_Pointer)
            pointee = pointee.pointeeType;

        return pointee.isConst;
    }

    auto result = translateType(type.pointeeType, rewriteIdToObjcObject, false);

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

string translateFunctionPointerType (Type type)
in
{
    assert(type.kind == CXTypeKind.CXType_BlockPointer || type.isFunctionPointerType);
}
body
{
    auto func = type.pointeeType.func;

    Parameter[] params;
    params.reserve(func.arguments.length);

    foreach (type ; func.arguments)
        params ~= Parameter(translateType(type));

    auto resultType = translateType(func.resultType);

    return translateFunction(resultType, "function", params, func.isVariadic, new String);
}

string translateObjCObjectPointerType (Type type)
in
{
    assert(type.kind == CXTypeKind.CXType_ObjCObjectPointer && !type.isObjCBuiltinType);
}
body
{
    auto pointee = type.pointeeType;

    if (pointee.spelling == "Protocol")
        return "Protocol*";

    else
        return translateType(pointee);
}

string translateType (CXTypeKind kind, bool rewriteIdToObjcObject = true)
{
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
                includeHandler.addCompatible();
                return "c_ulong";

            case CXType_ULongLong: return "ulong";
            case CXType_UInt128: return "<unimplemented>";
            case CXType_Char_S: return "char";
            case CXType_SChar: return "byte";
            case CXType_WChar: return "wchar";
            case CXType_Short: return "short";
            case CXType_Int: return "int";

            case CXType_Long:
                includeHandler.addCompatible();
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
            case CXType_Complex: return "<unimplemented>";
            case CXType_Pointer: return "<unimplemented>";
            case CXType_BlockPointer: return "<unimplemented>";
            case CXType_LValueReference: return "<unimplemented>";
            case CXType_RValueReference: return "<unimplemented>";
            case CXType_Record: return "<unimplemented>";
            case CXType_Enum: return "<unimplemented>";
            case CXType_Typedef: return "<unimplemented>";
            case CXType_FunctionNoProto: return "<unimplemented>";
            case CXType_FunctionProto: return "<unimplemented>";
            case CXType_Vector: return "<unimplemented>";
            default: assert(0, "Unhandled type kind " ~ kind.toString);
        }
}
