/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Visitor;

import clang.c.index;
import clang.Cursor;

struct Visitor
{
	alias int delegate (ref Cursor, ref Cursor) Delegate;
	alias int delegate (Delegate dg) OpApply;
	
	private CXCursor cursor;
	
	this (CXCursor cursor)
	{
		this.cursor = cursor;
	}
	
	this (Cursor cursor)
	{
		this.cursor = cursor.cx;
	}

	int opApply (Delegate dg)
	{
		auto result = clang_visitChildren(cursor, &visitorFunction, cast(CXClientData) &dg);
		return result == CXChildVisitResult.CXChildVisit_Break ? 1 : 0;
	}

private:

	extern (C) static CXChildVisitResult visitorFunction (CXCursor cursor, CXCursor parent, CXClientData data)
	{
		Delegate dg;
		auto tmp = cast(_Delegate*) data;
		
		dg.ptr = tmp.ptr;
		dg.funcptr = tmp.funcptr;
		
		with (CXChildVisitResult)
			return dg(Cursor(cursor), Cursor(parent)) ? CXChildVisit_Break : CXChildVisit_Continue;
	}
	
	struct _Delegate
	{
		void* ptr;
		int function (ref Cursor, ref Cursor) funcptr;
	}
	
	template Constructors ()
	{
		private Visitor visitor;

		this (Visitor visitor)
		{
			this.visitor = visitor;
		}

		this (CXCursor cursor)
		{
			visitor = Visitor(cursor);
		}
		
		this (Cursor cursor)
		{
			visitor = Visitor(cursor);
		}
	}
}

struct DeclarationVisitor
{
	mixin Visitor.Constructors;

	int opApply (Visitor.Delegate dg)
	{
		foreach (cursor, parent ; visitor)
			if (cursor.isDeclaration)
				if (auto result = dg(cursor, parent))
					return result;
				
		return 0;
	}
}

struct KindVisitor
{
	private Visitor visitor;
	private CXCursorKind kind;
	
	this (Visitor visitor, CXCursorKind kind)
	{
		this.visitor = visitor;
		this.kind = kind;
	}

	this (CXCursor cursor, CXCursorKind kind)
	{
		this(Visitor(cursor), kind);
	}
	
	this (Cursor cursor, CXCursorKind kind)
	{
		this(cursor.cx, kind);
	}

	int opApply (Visitor.Delegate dg)
	{
		foreach (cursor, parent ; visitor)
			if (cursor.kind == kind)
				if (auto result = dg(cursor, parent))
					return result;
				
		return 0;
	}
}