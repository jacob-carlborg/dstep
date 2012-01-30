/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.objc.ObjcInterface;

import std.string;

import dstep.converter.Declaration;
import dstep.util.Block;
import dstep.core.io;

import clang.c.index;
import clang.Cursor;
import clang.Util;

class ObjcInterface : Declaration
{
	mixin Constructors;
	
	void convert ()
	{
		println(spelling);
		
		foreach (cursor, parent ; cursor.declarations)
		{
			with (CXCursorKind)
				switch ()
				{
					case CXCursor_ObjCInstanceMethodDecl: convertInstanceMethod(cursor, parent); break;
					case CXCursor_ObjCClassMethodDecl: convertClasseMethod(cursor, parent); break;
					case CXCursor_ObjCPropertyDecl: convertProperty(cursor, parent); break;
					default: break;
				}
		}
	}

private:
	
	void convertInstanceMethod (Cursor cursor, Cursor parent)
	{
		string selector = cursor.spelling;
	}
	
	void convertClasseMethod (Cursor cursor, Cursor parent)
	{
		
	}
	
	void convertProperty (Cursor cursor, Cursor parent)
	{
		
	}
}