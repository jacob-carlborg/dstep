/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 30, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.Type;

import clang.c.index;

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
		if (type.kind == CXType_BlockPointer || isFunctionPointerType(type))
			return convertFunctionPointerType(type);
			
		if (type.kind == CXType_ObjCObjectPointer && !isObjCBuiltinType(type.kind))
			return convertObjCObjectPointerType(type);
			
		if (isWideCharType(type.kind))	
			return "wchar";
		
		switch (type.kind)
		{
			case CXType_Pointer: return convertType(type.pointee) ~ "*";
			case CXType_Bool: return "bool";
			case CXType_ObjCId: return rewriteIdToObject ? "Object" : "id";
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
	return "<unimplemented>";
}

bool isObjCBuiltinType (CXTypeKind kind)
{
	with (CXTypeKind)
		switch (kind)
		{
			case CXType_ObjCId:
			case CXType_ObjCClass:
			case CXType_ObjCSel:
				return true;
				
			default: return false;
		}
}

bool isWideCharType (CXTypeKind kind)
{
	with (CXTypeKind)
		return CXType_WChar || CXType_SChar;
}

bool isFunctionPointerType (Type type)
{
	with (CXTypeKind)
		return type.kind == CXType_Pointer && type.pointee.kind == CXType_FunctionProto;
}