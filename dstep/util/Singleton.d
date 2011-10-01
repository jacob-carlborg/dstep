/**
 * Copyright: Copyright (c) 2010-2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Aug 15, 2010
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.util.Singleton;

mixin template Singleton ()
{
	private static typeof(this) instance_;
	
	static typeof(this) instance ()
	{
		if (instance_)
			return instance_;
		
		return instance_ = new typeof(this);
	}

	static auto opDispatch (string name, Args...) (Args args)
	{
		mixin("return instance." ~ name ~ "(args);");
	}
	
	private this () {}
}