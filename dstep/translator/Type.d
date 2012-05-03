/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 30, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Type;

import std.string;

import mambo.core.string;
import mambo.core.io;

import clang.c.index;
import clang.Type;

import dstep.translator.Translator;
import dstep.translator.Output;

string convertType (Type type, bool rewriteIdToObject = true)
{
	with (CXTypeKind)
	{
		if (type.kind == CXType_BlockPointer || type.isFunctionPointerType)
			return convertFunctionPointerType(type);
			
		if (type.kind == CXType_ObjCObjectPointer && !type.isObjCBuiltinType)
			return convertObjCObjectPointerType(type);
			
		if (type.isWideCharType)	
			return "wchar";
			
		if (type.isObjCIdType)
			return rewriteIdToObject ? "Object" : "id";

		switch (type.kind)
		{
			case CXType_Pointer: return convertType(type.pointeeType) ~ "*";

			case CXType_Typedef: return convertTypedef(type);

			case CXType_Record:
			case CXType_Enum:
			case CXType_ObjCInterface:
				return type.spelling;

			default: return convertType(type.kind, rewriteIdToObject);
		}
	}
}

string convertSelector (string str, bool fullName = false)
{
	if (fullName)
		str = str.replace(":", "_");
		
	else
	{
		auto i = str.indexOf(":");
		
		if (i > -1)
			str = str[0 .. i];
	}

	return convertIdentifier(str);
}

private:

string convertTypedef (Type type)
in
{
    assert(type.kind == CXTypeKind.CXType_Typedef);
}
body
{
    auto spelling = type.spelling;
    
    if (spelling == "BOOL")
        spelling = "bool";

    return spelling;
}

string convertType (CXTypeKind kind, bool rewriteIdToObject = true)
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
			case CXType_ULong: return "c_ulong";
			case CXType_ULongLong: return "ulong";
			case CXType_UInt128: return "<unimplemented>";
			case CXType_Char_S: return "char";
			case CXType_SChar: return "<unimplemented>";
			case CXType_WChar: return "wchar";
			case CXType_Short: return "short";
			case CXType_Int: return "int";
			case CXType_Long: return "c_long";
			case CXType_LongLong: return "long";
			case CXType_Int128: return "<unimplemented>";
			case CXType_Float: return "float";
			case CXType_Double: return "double";
			case CXType_LongDouble: return "real";
			case CXType_NullPtr: return "null";
			case CXType_Overload: return "<unimplemented>";
			case CXType_Dependent: return "<unimplemented>";
			case CXType_ObjCId: return rewriteIdToObject ? "Object" : "id";
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
			case CXType_ConstantArray: return "<unimplemented>";
			case CXType_Vector: return "<unimplemented>";
			default: assert(0, "Unhandled type kind");
		}
}

string convertFunctionPointerType (Type type)
{
	auto func = type.pointeeType.func;

	Parameter[] params;
	params.reserve(func.arguments.length);
	
	foreach (type ; func.arguments)
		params ~= Parameter(convertType(type));

	auto resultType = convertType(func.resultType);
	
	return convertFunction(resultType, "function", params, func.isVariadic, new String).data;
}

string convertObjCObjectPointerType (Type type)
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
        return convertType(pointee);
}