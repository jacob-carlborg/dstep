/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 1, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Cursor;

import clang.c.index;
import clang.SourceLocation;
import clang.Util;
import clang.Visitor;

struct Cursor
{
	mixin CX;
	
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
	
	@property isDeclaration ()
	{
		return clang_isDeclaration(kind);
	}
	
	@property DeclarationVisitor declarations ()
	{
		return DeclarationVisitor(cx);
	}
	
	@property ObjcCursor objc ()
	{
		return ObjcCursor(this);
	}
	
	@property KindVisitor parameters ()
	{
		return KindVisitor(cursor, CXCursorKind.CXCursor_ParmDecl);
	}
}

struct ObjcCursor
{
	private Cursor cursor;
	alias cursor this;
	
	@property KindVisitor instanceMethods ()
	{
		return KindVisitor(cursor, CXCursorKind.CXCursor_ObjCInstanceMethodDecl);
	}
	
	@property KindVisitor classMethods ()
	{
		return KindVisitor(cursor, CXCursorKind.CXCursor_ObjCClassMethodDecl);
	}
	
	@property KindVisitor properties ()
	{
		return KindVisitor(cursor, CXCursorKind.CXCursor_ObjCPropertyDecl);
	}
}