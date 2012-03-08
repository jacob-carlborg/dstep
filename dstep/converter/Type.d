/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 30, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.Type;

import std.string;

import mambo.core.string;
import mambo.core.io;

import clang.c.index;
import clang.Type;

import dstep.converter.Converter;

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
			case CXType_Pointer: return convertType(type.pointee) ~ "*";

			case CXType_Record:
			case CXType_Enum:
			case CXType_Typedef:
				return type.spelling;

			default: return convertType(type.kind, rewriteIdToObject);
		}
	}
}

string convertType (CXTypeKind kind, bool rewriteIdToObject = true)
{
	with (CXTypeKind)
		switch (kind)
		{
			case CXType_Invalid: return "";
			case CXType_Unexposed: return "";
			case CXType_Void: return "void";
			case CXType_Bool: return "bool";
			case CXType_Char_U: return "";
			case CXType_UChar: return "";
			case CXType_Char16: return "wchar";
			case CXType_Char32: return "dchar";
			case CXType_UShort: return "ushort";
			case CXType_UInt: return "uint";
			case CXType_ULong: return "c_ulong";
			case CXType_ULongLong: return "ulong";
			case CXType_UInt128: return "";
			case CXType_Char_S: return "char";
			case CXType_SChar: return "";
			case CXType_WChar: return "wchar";
			case CXType_Short: return "short";
			case CXType_Int: return "int";
			case CXType_Long: return "c_long";
			case CXType_LongLong: return "long";
			case CXType_Int128: return "";
			case CXType_Float: return "float";
			case CXType_Double: return "double";
			case CXType_LongDouble: return "";
			case CXType_NullPtr: return "null";
			case CXType_Overload: return "";
			case CXType_Dependent: return "";
			case CXType_ObjCId: return rewriteIdToObject ? "Object" : "id";
			case CXType_ObjCClass: return "Class";
			case CXType_ObjCSel: return "SEL";
			case CXType_Complex: return "";
			case CXType_Pointer: return "";
			case CXType_BlockPointer: return "";
			case CXType_LValueReference: return "";
			case CXType_RValueReference: return "";
			case CXType_Record: return "";
			case CXType_Enum: return "";
			case CXType_Typedef: return "";
			case CXType_ObjCInterface: return "";
			case CXType_ObjCObjectPointer: return "";
			case CXType_FunctionNoProto: return "";
			case CXType_FunctionProto: return "";
			case CXType_ConstantArray: return "";
			case CXType_Vector: return "";
			default: return "";
		}
}

string convertFunctionPointerType (Type type)
{
	return "<unimplemented>";
}

string convertObjCObjectPointerType (Type type)
{
	if (type.kind == CXTypeKind.CXType_ObjCObjectPointer && !type.isObjCBuiltinType)
	{
		auto pointee = type.pointee;
		
		if (pointee.spelling == "Protocol")
			return "Protocol*";

		return convertType(pointee);
	}
	
	return convertType(type);
}

string convertSelector (string str, bool fullName = false)
{
	if (fullName)
		str = str.replace(":", "_");
		
	else
		str = str.chomp(":");
		
	return convertIdentifier(str);
}