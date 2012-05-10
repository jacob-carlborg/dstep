/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: may 10, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Enum;

import mambo.core._;

import clang.c.index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Translator;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Type;

class Enum : Declaration
{
	this (Cursor cursor, Cursor parent, Translator translator)
	{
		super(cursor, parent, translator);
	}
	
	void translate ()
	{
		writeEnum(spelling) in (context) {
			foreach (cursor, parent ; cursor.declarations)
			{
				with (CXCursorKind)
					switch (cursor.kind)
					{
						case CXCursor_EnumConstantDecl:
							auto str = new String;
							str ~= translateIdentifier(cursor.spelling);
							str ~= " = ";
							str ~= cursor.enum_.value.toString;
							context.instanceVariables ~= str;
						break;
						
						default: break;
					}
			}
		};
	}

private:

	Block!(EnumData) writeEnum (string name)
	{
		Block!(EnumData) block;
		
		block.dg = (dg) {
			auto context = new EnumData;
			output.structs ~= context;
			context.name = translateIdentifier(name);
			
			dg(context);
		};
		
		return block;
	}
}