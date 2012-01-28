/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.TranslationUnit;

import std.string;

import clang.c.index;
import clang.Cursor;
import clang.Diagnostic;
import clang.Index;
import clang.UnsavedFile;
import clang.Util;

import dstep.core.io;

struct TranslationUnit
{
	mixin CX;
	alias int delegate (int delegate (ref Cursor, ref Cursor) dg) DeclarationVisitor;
	
	static TranslationUnit parse (Index index, string sourceFilename, string[] commandLineArgs,
		UnsavedFile[] unsavedFiles = null,
		uint options = CXTranslationUnit_Flags.CXTranslationUnit_None)
	{
		return TranslationUnit(
			clang_parseTranslationUnit(
				index.cx,
				sourceFilename.toStringz,
				strToCArray(commandLineArgs),
				cast(int) commandLineArgs.length,
				toCArray!(CXUnsavedFile)(unsavedFiles),
				cast(uint) unsavedFiles.length,
				options));
	}
	
	private this (CXTranslationUnit cx)
	{
		this.cx = cx;
	}
	
	@property DiagnosticIterator diagnostics ()
	{
		return DiagnosticIterator(cx);
	}
	
	@property DeclarationVisitor declarations ()
	{
		return &visitorDelegate;
	}
	
	private int visitorDelegate (int delegate (ref Cursor, ref Cursor) dg)
	{
		auto start = clang_getTranslationUnitCursor(cx);
		auto result = clang_visitChildren(start, &visitorFunction, cast(CXClientData) &dg);
		
		return result == CXChildVisitResult.CXChildVisit_Break ? 1 : 0;
	}
	
	private struct Delegate
	{
		void* ptr;
		int function (ref Cursor, ref Cursor) funcptr;
	}
	
	extern (C) private static CXChildVisitResult visitorFunction (CXCursor cursor, CXCursor parent, CXClientData data)
	{
		int delegate (ref Cursor, ref Cursor) dg;
		auto tmp = cast(Delegate*) data;
		
		dg.ptr = tmp.ptr;
		dg.funcptr = tmp.funcptr;
		auto result = cast(CXChildVisitResult) dg(Cursor(cursor), Cursor(parent));

		switch (result)
		{
			case CXChildVisitResult.CXChildVisit_Recurse:
				return result;

			case CXChildVisitResult.CXChildVisit_Break:
				return CXChildVisitResult.CXChildVisit_Continue;
				
			default: return CXChildVisitResult.CXChildVisit_Break;
		}
	}
}

struct DiagnosticIterator
{
	private CXTranslationUnit translatoinUnit;
	
	this (CXTranslationUnit translatoinUnit)
	{
		this.translatoinUnit = translatoinUnit;
	}
	
	size_t length ()
	{
		return clang_getNumDiagnostics(translatoinUnit);
	}
	
	int opApply (int delegate (ref Diagnostic) dg)
	{
		int result;
		
		foreach (i ; 0 .. length)
		{
			auto diag = clang_getDiagnostic(translatoinUnit, cast(uint) i);
			result = dg(Diagnostic(diag));

			if (result)
				break;
		}
		
		return result;
	}
}