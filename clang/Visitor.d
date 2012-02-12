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

struct TypedVisitor (CXCursorKind kind)
{
	private Visitor visitor;
	
	this (Visitor visitor)
	{
		this.visitor = visitor;
	}

	this (CXCursor cursor)
	{
		this(Visitor(cursor));
	}
	
	this (Cursor cursor)
	{
		this(cursor.cx);
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

alias TypedVisitor!(CXCursorKind.CXCursor_ObjCInstanceMethodDecl) ObjCInstanceMethodVisitor;
alias TypedVisitor!(CXCursorKind.CXCursor_ObjCClassMethodDecl) ObjCClassMethodVisitor;
alias TypedVisitor!(CXCursorKind.CXCursor_ObjCPropertyDecl) ObjCPropertyVisitor;
alias TypedVisitor!(CXCursorKind.CXCursor_ObjCProtocolRef ) ObjCProtocolVisitor;

struct ParamVisitor
{
	mixin Visitor.Constructors;
	
	int opApply (int delegate (ref ParamCursor) dg)
	{
		foreach (cursor, parent ; visitor)
			if (cursor.kind == CXCursorKind.CXCursor_ParmDecl)
				if (auto result = dg(ParamCursor(cursor)))
					return result;

		return 0;
	}
	
	@property bool any ()
	{
		//return clang_getNumArgTypes(visitor.cursor.type);
		return false;
	}
}