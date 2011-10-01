/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.TranslationUnit;

import std.string;

import clang.c.index;
import clang.UnsavedFile;
import clang.Index;

struct TranslationUnit
{
	mixin CX;
	
	static TranslationUnit parse (Index index, string sourceFilename, string[] commandLineArgs,
		UnsavedFile[] unsavedFiles = null,
		uint options = CXTranslationUnit_Flags.CXTranslationUnit_None)
	{
		TranslationUnit tu;
		
		tu.cx = clang_parseTranslationUnit(index.cx,
			sourceFilename.toString,
			commandLineArgs.toCArray,
			commandLineArgs.length,
			unsavedFiles.toCArray,
			unsavedFiles.length,
			options);
			
		return tu;
	}
}