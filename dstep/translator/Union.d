/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 19, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Union;

import mambo.core._;

import clang.c.index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Translator;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Type;

class Union : Declaration
{
	this (Cursor cursor, Cursor parent, Translator translator)
	{
		super(cursor, parent, translator);
	}
	
	string translate ()
	{
		return writeUnion(spelling, (context) {
			foreach (cursor, parent ; cursor.declarations)
			{
				with (CXCursorKind)
					switch (cursor.kind)
					{
						case CXCursor_FieldDecl:
							context.instanceVariables ~= translator.variable(cursor, new String);
						break;
						
						default: break;
					}
			}
		});
	}

private:

	string writeUnion (string name, void delegate (UnionData context) dg)
	{
		auto context = new UnionData;
		context.name = translateIdentifier(name);

		dg(context);
		
		return context.data;
	}
}