/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.File;

import clang.c.index;
import clang.Util;

struct File
{
	mixin CX;
	
	@property string name ()
	{
		return toD(clang_getFileName(cx));
	}
}