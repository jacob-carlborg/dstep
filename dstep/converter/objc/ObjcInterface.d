/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.objc.ObjcInterface;

import std.string;

import mambo.core.io;
import mambo.core.Block;
import mambo.core.string;

import clang.c.index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.converter.Declaration;
import dstep.converter.Output;
import dstep.converter.Type;

class ObjcInterface : Declaration
{
	mixin Constructors;
	
	void convert ()
	{
		auto cursor = cursor.objc;

		writeClass(spelling, cursor.superClass.spelling, collectInterfaces(cursor.objc)) in {
			foreach (cursor, parent ; cursor.declarations)
			{
				with (CXCursorKind)
					switch (cursor.kind)
					{
						case CXCursor_ObjCInstanceMethodDecl: convertInstanceMethod(cursor.func); break;
						case CXCursor_ObjCClassMethodDecl: convertClasseMethod(cursor); break;
						case CXCursor_ObjCPropertyDecl: convertProperty(cursor); break;
						default: break;
					}
		
			}
		};
	}

private:
	
	string[] collectInterfaces (ObjcCursor cursor)
	{
		string[] interfaces;

		foreach (cursor , parent ; cursor.protocols)
			interfaces ~= convertIdentifier(cursor.spelling);

		return interfaces;
	}
	
	Block writeClass (string name, string superClassName, string[] interfaces)
	{
		Block block;
		
		block.dg = (void delegate () dg){
			output.classes ~= output.currentClass;
			output.currentClass = new Class;
			output.currentClass ~= "class ";
			output.currentClass ~= convertIdentifier(name);
			
			if (superClassName.isPresent)
			{
				output.currentClass ~= " : ";
				output.currentClass ~= convertIdentifier(superClassName);
			}
			
			classInterfaceHelper(interfaces, output.currentClass, dg);
		};
		
		return block;
	}
	
	void classInterfaceHelper (string[] interfaces, Class current, void delegate () dg)
	{
		if (interfaces.any)
		{
			current ~= " : ";
			current ~= interfaces.join(", ");
		}

		current ~= nl;
		current ~= "{";
		current ~= nl;
		current.indent in { dg(); };
		current ~= "}";
		current ~= nl;
		current ~= nl;
	}
	
	void convertInstanceMethod (FunctionCursor func)
	{
		auto current = output.currentClass;

		current ~= convertType(func.resultType);
		current ~= " ";
		current ~= current.getMethodName(func) ~ " (";

		string[] params;
		
		foreach (param ; func.parameters)
		{
			auto p = convertType(param.type);
			p ~= " " ~ convertIdentifier(param.spelling);
			params ~= p;
		}
		
		current ~= params.join(",");

		if (func.isVariadic)
		{
			if (func.parameters.any)
				current ~= ", ";

			current ~= "...";
		}

		current ~= ") [";
		current ~= func.spelling;
		current ~= "];";
		current ~= nl;
	}
	
	void convertClasseMethod (Cursor cursor)
	{
		
	}
	
	void convertProperty (Cursor cursor)
	{
		
	}
}