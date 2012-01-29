/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.Declaration;

import clang.Cursor;

import dstep.converter.Output;

abstract class Declaration
{
	protected
	{
		Cursor cursor;
		Cursor parent;

		Output output;
	}

	template Constructors ()
	{
		import clang.Cursor;
		import dstep.converter.Output;
		
		this (Cursor cursor, Cursor parent, Output output)
		{
			super(cursor, parent, output);
		}
	}
	
	this (Cursor cursor, Cursor parent, Output output)
	{
		this.cursor = cursor;
		this.parent = parent;
		this.output = output;
	}
	
	abstract void convert ();
	
	@property spelling ()
	{
		return cursor.spelling;
	}
}