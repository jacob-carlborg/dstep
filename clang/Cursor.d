/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 1, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Cursor;

import clang.c.index;
import clang.SourceLocation;
import clang.Type;
import clang.Util;
import clang.Visitor;

struct Cursor
{
	mixin CX;
	
	@property static Cursor empty ()
	{
		auto r = clang_getNullCursor();
		return Cursor(r);
	}
	
	@property string spelling ()
	{
		return toD(clang_getCursorSpelling(cx));
	}
	
	@property CXCursorKind kind ()
	{
		return clang_getCursorKind(cx);
	}
	
	@property SourceLocation location ()
	{
		return SourceLocation(clang_getCursorLocation(cx));
	}
	
	@property Type type ()
	{
		auto r = clang_getCursorType(cx);
		return Type(r);
	}
	
	@property bool isDeclaration ()
	{
		return clang_isDeclaration(cx.kind) != 0;
	}
	
	@property DeclarationVisitor declarations ()
	{
		return DeclarationVisitor(cx);
	}
	
	@property ObjcCursor objc ()
	{
		return ObjcCursor(this);
	}

	@property FunctionCursor func ()
	{
		return FunctionCursor(this);
	}
	
	@property bool isValid ()
	{
		return !clang_isInvalid(cx.kind);
	}
	
	@property Visitor all ()
	{
		return Visitor(this);
	}
}

struct ObjcCursor
{
	Cursor cursor;
	alias cursor this;
	
	@property ObjCInstanceMethodVisitor instanceMethods ()
	{
		return ObjCInstanceMethodVisitor(cursor);
	}
	
	@property ObjCClassMethodVisitor classMethods ()
	{
		return ObjCClassMethodVisitor(cursor);
	}
	
	@property ObjCPropertyVisitor properties ()
	{
		return ObjCPropertyVisitor(cursor);
	}
	
	@property Cursor superClass ()
	{
		foreach (cursor, parent ; TypedVisitor!(CXCursorKind.CXCursor_ObjCSuperClassRef)(cursor))
			return cursor;

		return Cursor.empty;
	}
	
	@property ObjCProtocolVisitor protocols ()
	{
		return ObjCProtocolVisitor(cursor);
	}
}

struct FunctionCursor
{
	Cursor cursor;
	alias cursor this;
	
	@property Type resultType ()
	{
		auto r = clang_getCursorResultType(cx);
		return Type(r);
	}
	
	@property bool isVariadic ()
	{
		//return clang_isFunctionTypeVariadic(type.cx);
		return false;
	}
	
	@property ParamVisitor parameters ()
	{
		return ParamVisitor(cx);
	}
}

struct ParamCursor
{
	Cursor cursor;
	alias cursor this;
}