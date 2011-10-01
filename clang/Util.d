/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Util;

import clang.c.index;

import std.string;

immutable(char)** strToCArray (string[] arr)
{
	if (!arr)
		return null;
	
	immutable(char)*[] cArr;
	cArr.reserve(arr.length);
	
	foreach (str ; arr)
		cArr ~= str.toStringz;
	
	return cArr.ptr;
}

template isCX (T)
{
	enum bool isCX = __traits(hasMember, T, "cx");
}

template cxName (T)
{
	enum cxName = "CX" ~ T.stringof;
}

U* toCArray (U, T) (T[] arr)
{
	if (!arr)
		return null;
		
	U[] cArr;
	cArr.reserve(arr.length);
	
	foreach (e ; arr)
		cArr ~= e.cx;
		
	return cArr.ptr;
}

mixin template CX ()
{
	mixin("private alias " ~ cxName!(typeof(this)) ~ " CType;");
	
	CType cx_;
	
	@disable this ();
	
	this (CType cx)
	{
		cx_ = cx;
	}
	
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
		enum methodCall = "clang_dispose" ~ typeof(this).stringof ~ "(cx);";
		
		static if (false && __traits(compiles, methodCall))
			mixin(methodCall);
	}
}