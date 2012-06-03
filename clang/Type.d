/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Type;

import clang.c.index;
import clang.Cursor;
import clang.Util;

struct Type
{
	mixin CX;

	@property string spelling ()
	{
		auto r = clang_getTypeDeclaration(cx);
		return Cursor(r).spelling;
	}
	
	@property bool isTypedef ()
	{
		return kind == CXTypeKind.CXType_Typedef;
	}
	
	@property Type canonicalType ()
	{
		auto r = clang_getCanonicalType(cx);
		return Type(r);
	}
	
	@property Type pointeeType ()
	{
		auto r = clang_getPointeeType(cx);
		return Type(r);
	}
	
	@property bool isValid ()
	{
	    return kind != CXTypeKind.CXType_Invalid;
	}
	
	@property bool isFunctionType ()
	{
		with (CXTypeKind)
			return kind == CXType_FunctionNoProto ||
				kind == CXType_FunctionProto || 
				// FIXME: This "hack" shouldn't be needed.
				func.resultType.isValid;
	}
	
	@property bool isFunctionPointerType ()
	{
		with (CXTypeKind)
			return kind == CXType_Pointer && pointeeType.isFunctionType;
	}
	
	@property bool isObjCIdType ()
	{
		return isTypedef &&
			canonicalType.kind ==  CXTypeKind.CXType_ObjCObjectPointer &&
			spelling == "id";
	}
	
	@property bool isObjCClassType ()
	{
		return isTypedef &&
			canonicalType.kind ==  CXTypeKind.CXType_ObjCObjectPointer &&
			spelling == "Class";
	}
	
	@property bool isObjCSelType ()
	{
		with(CXTypeKind)
			if (isTypedef)
			{
				auto c = canonicalType;
				return c.kind == CXType_Pointer &&
					c.pointeeType.kind == CXType_ObjCSel;
			}
		
			else
				return false;
	}
	
	@property bool isObjCBuiltinType ()
	{
		return isObjCIdType || isObjCClassType || isObjCSelType;
	}

	@property bool isWideCharType ()
	{
		with (CXTypeKind)
			return kind == CXType_WChar || kind == CXType_SChar;
	}
	
	@property bool isConst ()
	{
		return clang_isConstQualifiedType(cx) == 1;
	}
	
	@property bool isUnexposed ()
	{
		return kind == CXTypeKind.CXType_Unexposed;
	}
	
	@property Cursor declaration ()
	{
	    auto r = clang_getTypeDeclaration(cx);
	    return Cursor(r);
	}
	
	@property FuncType func ()
	{
		return FuncType(this);
	}
	
	@property ArrayType array ()
	{
		return ArrayType(this);
	}
}

struct FuncType
{
	Type type;
	alias type this;

	@property Type resultType ()
	{
		auto r = clang_getResultType(type.cx);
		return Type(r);
	}
	
	@property Arguments arguments ()
	{
		return Arguments(this);
	}
	
	@property bool isVariadic ()
	{
		return clang_isFunctionTypeVariadic(type.cx) == 1;
	}
}

struct ArrayType
{
	Type type;
	alias type this;
	
	@property Type elementType ()
	{
		auto r = clang_getArrayElementType(cx);
		return Type(r);
	}
	
	@property long size ()
	{
		return clang_getArraySize(cx);
	}
}

struct Arguments
{
	FuncType type;
	
    @property size_t length ()
    {
		return clang_getNumArgTypes(type.type.cx);
    }

	Type opIndex (size_t i)
	{
		auto r = clang_getArgType(type.type.cx, i);
		return Type(r);
	}
	
	int opApply (int delegate (ref Type) dg)
	{
		foreach (i ; 0 .. length)
		{
			auto type = this[i];
			
			if (auto result = dg(type))
				return result;
		}

		return 0;
	}
}

@property bool isUnsigned (CXTypeKind kind)
{
	with (CXTypeKind)
		switch (kind)
		{
			case CXType_Char_U: return true;
			case CXType_UChar: return true;
			case CXType_UShort: return true;
			case CXType_UInt: return true;
			case CXType_ULong: return true;
			case CXType_ULongLong: return true;
			case CXType_UInt128: return true;

			default: return false;
		}
}