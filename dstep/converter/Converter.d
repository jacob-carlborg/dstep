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

import dstep.core.io;

class Converter
{
	TranslationUnit translationUnit;
	
	this (TranslationUnit translationUnit)
	{
		this.translationUnit = translationUnit;
	}
	
	void convert ()
	{
		foreach (cursor, parent ; translationUnit.declarations)
		{
			CXFile file;
			
			clang_getSpellingLocation(cursor.location, &file, null, null, null);
			auto str = toD(clang_getFileName(file));
			println(str);
			println(cursor.spelling);
		}
	}
}