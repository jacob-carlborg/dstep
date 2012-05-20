/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.objc.ObjcInterface;

import std.string;

import mambo.core._;

import clang.c.index;
import clang.Cursor;
import clang.Visitor;
import clang.Util;

import dstep.translator.Translator;
import dstep.translator.Declaration;
import dstep.translator.Output;
import dstep.translator.Type;

class ObjcInterface : Declaration
{
	this (Cursor cursor, Cursor parent, Translator translator)
	{
		super(cursor, parent, translator);
	}

	string translate ()
	{
		auto cursor = cursor.objc;

		return writeClass(spelling, cursor.superClass.spelling, collectInterfaces(cursor.objc), {
			foreach (cursor, parent ; cursor.declarations)
			{
				with (CXCursorKind)
					switch (cursor.kind)
					{
						case CXCursor_ObjCInstanceMethodDecl: translateMethod(cursor.func); break;
						case CXCursor_ObjCClassMethodDecl: translateMethod(cursor.func, true); break;
						case CXCursor_ObjCPropertyDecl: translateProperty(cursor.func); break;
						case CXCursor_ObjCIvarDecl: translateInstanceVariable(cursor); break;
						default: break;
					}
			}
		});
	}

private:
	
	string[] collectInterfaces (ObjcCursor cursor)
	{
		string[] interfaces;

		foreach (cursor , parent ; cursor.protocols)
			interfaces ~= translateIdentifier(cursor.spelling);

		return interfaces;
	}
	
	string writeClass (string name, string superClassName, string[] interfaces, void delegate () dg)
	{
		output.currentClass = new ClassData;
		output.currentClass.name = translateIdentifier(name);
		
		if (superClassName.isPresent)
			output.currentClass.superclass ~= translateIdentifier(superClassName);
		
		dg();
		
		return output.currentClass.data;
	}
	
	void translateMethod (FunctionCursor func, bool classMethod = false, string name = null)
	{
		auto method = new String;
		auto cls = output.currentClass;
		
		name = cls.getMethodName(func, name);
		
		translateFunction(func, name, method, classMethod);

		method ~= " [";
		method ~= func.spelling;
		method ~= "];";
		
		
		if (classMethod)
			cls.staticMethods ~= method.data;
			
		else
			cls.instanceMethods ~= method.data;
	}
	
	void translateProperty (FunctionCursor cursor)
	{
		
	}
	
	void translateInstanceVariable (Cursor cursor)
	{
		auto var = new String;
		translator.variable(cursor, var);
		output.currentClass.instanceVariables ~= var.data;
	}
}