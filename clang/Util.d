/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Util;

import std.string;

char** toCArray (string[] arr)
{
	if (!arr)
		return null;
	
	char*[] cArr;
	cArr.reserve(arr.length);
	
	foreach (str ; arr)
		cArr ~= str.toStringz;
	
	cArr.ptr;
}

template isCX (T)
{
	enum isCX = __traits(compile, { T t; auto = t.cx; });
}

template cxName (T)
{
	enum cxName = "CX" ~ T.stringof;
}

template toCArray (T) if (isCX!(T))
{
	mixin("alias " ~ cxName!(T) ~ " CType;");
	
	CType* toCArray (T[] arr)
	{
		if (!arr)
			return null;
			
		CType[] cArr;
		cArr.reserve(arr.length);
		
		foreach (e ; arr)
			cArr ~= e.cx;
			
		return cArr.ptr;
	}
}

mixin template CX ()
{
	mixin("private alias " ~ cxName!(typeof(this)) ~ " CType;");
	
	CType cx_;
	
	@disable this ();
	
	CType cx ()
	{
		return cx_;
	}
	
	private CType cx (CType cx)
	{
		return cx_ = cx;
	}
	
	void dispose ()
	{
		mixin("clang_dispose" ~ typeof(this).stringof ~ "(cx);");
	}
}