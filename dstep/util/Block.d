/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.util.Block;

struct Block
{
	private void delegate (void delegate ()) dg;
	
	void opIn (void delegate () block)
	{
		dg(block);
	}
}