/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.Converter;

import clang.c.index;
import clang.TranslationUnit;
import clang.Util;

import dstep.converter.Declaration;
import dstep.converter.Output;
import dstep.converter.objc.ObjcInterface;
import dstep.core.io;

class Converter
{
	private
	{
		TranslationUnit translationUnit;
		Output output;
	}
	
	this (TranslationUnit translationUnit)
	{
		this.translationUnit = translationUnit;
		output = new Output;
	}
	
	void convert ()
	{
		foreach (cursor, parent ; translationUnit.declarations)
		{
			Declaration declaration;

			with (CXCursorKind)
				switch (cursor.kind)
				{
					case CXCursor_ObjCInterfaceDecl: declaration = new ObjcInterface(cursor, parent, output); break;
					default: continue;
				}

			declaration.convert;
		}
	}
}