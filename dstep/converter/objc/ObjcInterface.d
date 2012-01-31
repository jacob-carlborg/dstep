/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.objc.ObjcInterface;

import std.string;

import dstep.converter.Declaration;
import dstep.converter.Output;
import dstep.converter.Type;
import dstep.core.io;
import dstep.util.Block;

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
					case CXCursor_ObjCInstanceMethodDecl: convertInstanceMethod(cursor); break;
					case CXCursor_ObjCClassMethodDecl: convertClasseMethod(cursor); break;
					case CXCursor_ObjCPropertyDecl: convertProperty(cursor); break;
					default: break;
				}

		}
	}

private:
	
	void convertInstanceMethod (FunctionCursor func, Class current)
	{
		auto output = output.currentClass;
		
		output ~= convertType(func.type.result);
		output ~= dMethodName(func.spelling) ~ " (";
		
		if (func.parameters.any)
		{
			foreach (param ; func.parameters)
			{
				output ~= convertType(param.type.spelling);
				output ~= " " ~ convertIdentifier(param.spelling);
			}
		}
		
		if (func.isVariadic)
		{
			if (func.parameters.any)
				output ~= ", ";
				
			output ~= "...";
		}
		
		output ~= ") [";
		output ~= func.spelling;
		output.appendnl("];");
	}
	
	void convertClasseMethod (Cursor cursor, Class current)
	{
		
	}
	
	void convertProperty (Cursor cursor, Class current)
	{
		
	}
	
	void string dMethodName (string str)
	{
		return str;
	}
}