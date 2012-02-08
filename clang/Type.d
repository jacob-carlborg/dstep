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
import mambo.core.io;
struct Type
{
	mixin CX;
	
	@property Type pointee ()
	{
		return Type(clang_getPointeeType(cx));
	}
	
	@property string spelling ()
	{
		return Cursor(clang_getTypeDeclaration(cx)).spelling;
	}
	
	@property bool isFunctionType ()
	{
		with (CXTypeKind)
			switch (cx.kind)
			{
				case CXType_BlockPointer:
				case CXType_FunctionNoProto:
				case CXType_FunctionProto:
					return true;
			
				default: return isFunctionPointerType;
			}
	}
	
	@property bool isFunctionPointerType ()
	{
		with (CXTypeKind)
			return kind == CXType_Pointer && pointee.kind == CXType_FunctionProto;
	}
	
	@property bool isObjCBuiltinType ()
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

	@property bool isWideCharType ()
	{
		with (CXTypeKind)
			return kind == CXType_WChar || kind == CXType_SChar;
	}
}