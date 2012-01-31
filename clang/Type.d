/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Type;

import clang.c.index;
import clang.Cursor;
import clang.Util;

struct Type
{
	mixin CX;
	
	@property Type pointee ()
	{
		return Type(clang_getPointeeType(cx));
	}
	
	@property string spelling ()
	{
		return Cursor(clang_getTypeDeclaration(cx)).spelling;
	}
}