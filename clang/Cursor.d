/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 1, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Cursor;

import clang.c.index;
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
	
	@property CXSourceLocation location ()
	{
		return clang_getCursorLocation(cx);
	}
	
	@property isDeclaration ()
	{
		return clang_isDeclaration(kind);
	}
}