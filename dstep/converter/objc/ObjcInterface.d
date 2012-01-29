/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.objc.ObjcInterface;

import dstep.converter.Declaration;
import dstep.util.Block;
import dstep.core.io;

class ObjcInterface : Declaration
{
	mixin Constructors;
	
	void convert ()
	{
		println(spelling);
		
		foreach (cursor, parent ; cursor.declarations)
		{
			println(cursor.spelling);
		}
	}
}