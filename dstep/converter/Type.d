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

string convertType (string str)
{
	switch (str)
	{
		case "long": return "c_long";
		case "BOOL": return "bool";
		case "unsigned":
		case "unsigned int": return "uint";
		default: return str;
	}
}

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
			case CXType_Bool: return "bool";
			case CXType_Void: return "void";
			default: return convertType(type.spelling);
		}
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