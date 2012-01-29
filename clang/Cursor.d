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
}

struct Visitor
{
	private CXCursor cursor;
	private alias int delegate (ref Cursor, ref Cursor) VisitorDelegate;

	int opApply (VisitorDelegate dg)
	{
		auto result = clang_visitChildren(cursor, &visitorFunction, cast(CXClientData) &dg);
		return result == CXChildVisitResult.CXChildVisit_Break ? 1 : 0;
	}

private:

	extern (C) static CXChildVisitResult visitorFunction (CXCursor cursor, CXCursor parent, CXClientData data)
	{
		VisitorDelegate dg;
		auto tmp = cast(Delegate*) data;
		
		dg.ptr = tmp.ptr;
		dg.funcptr = tmp.funcptr;
		
		with (CXChildVisitResult)
			return dg(Cursor(cursor), Cursor(parent)) ? CXChildVisit_Break : CXChildVisit_Continue;
	}
	
	struct Delegate
	{
		void* ptr;
		int function (ref Cursor, ref Cursor) funcptr;
	}
}

struct DeclarationVisitor
{
	private Visitor visitor;
	
	this (CXCursor cursor)
	{
		visitor = Visitor(cursor);
	}
	
	this (Visitor visitor)
	{
		this.visitor = visitor;
	}

	int opApply (Visitor.VisitorDelegate dg)
	{
		foreach (cursor, parent ; visitor)
			if (auto result = dg(cursor, parent))
				return result;
				
		return 0;
	}
}