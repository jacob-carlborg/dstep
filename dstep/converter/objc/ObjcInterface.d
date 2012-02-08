/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.objc.ObjcInterface;

import std.string;

import mambo.core.io;

import dstep.converter.Declaration;
import dstep.converter.Output;
import dstep.converter.Type;

import clang.c.index;
import clang.Cursor;
import clang.Util;

class ObjcInterface : Declaration
{
	mixin Constructors;
	
	void convert ()
	{
		foreach (cursor, parent ; cursor.declarations)
		{
			if (cursor.spelling != "forwardingTargetForSelector:")
				continue;

			with (CXCursorKind)
				switch (cursor.kind)
				{
					case CXCursor_ObjCInstanceMethodDecl: convertInstanceMethod(cursor.func); break;
					case CXCursor_ObjCClassMethodDecl: convertClasseMethod(cursor); break;
					case CXCursor_ObjCPropertyDecl: convertProperty(cursor); break;
					default: break;
				}

		}
	}

private:
	
	void convertInstanceMethod (FunctionCursor func)
	{
		auto current = output.currentClass;

		current ~= convertType(func.resultType);
		current ~= " ";
		current ~= current.getMethodName(func) ~ " (";

		if (func.parameters.any)
		{
			foreach (param ; func.parameters)
			{
				current ~= convertType(param.type.spelling);
				current ~= " " ~ convertIdentifier(param.spelling);
			}
		}

		if (func.isVariadic)
		{
			if (func.parameters.any)
				current ~= ", ";

			current ~= "...";
		}

		current ~= ") [";
		current ~= func.spelling;
		current ~= "];";
		current ~= nl;
	}
	
	void convertClasseMethod (Cursor cursor)
	{
		
	}
	
	void convertProperty (Cursor cursor)
	{
		
	}
}