/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 1, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Struct;

import mambo.core._;

import clang.c.index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Translator;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Type;

class Struct : Declaration
{
	this (Cursor cursor, Cursor parent, Translator translator)
	{
		super(cursor, parent, translator);
	}
	
	void convert ()
	{
		writeStruct(spelling) in (context) {
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
		};
	}

private:

	Block!(StructData) writeStruct (string name)
	{
		Block!(StructData) block;
		
		block.dg = (dg) {
			auto context = new StructData;
			output.structs ~= context;
			context.name = convertIdentifier(name);
			
			dg(context);
		};
		
		return block;
	}
}