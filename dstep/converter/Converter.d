/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.Converter;

import std.file;

import mambo.core.io;
import mambo.core.string;

import clang.c.index;
import clang.Cursor;
import clang.File;
import clang.TranslationUnit;
import clang.Util;

import dstep.converter.Declaration;
import dstep.converter.Output;
import dstep.converter.objc.ObjcInterface;
import dstep.converter.Struct;
import dstep.converter.Type;

class Converter
{
	private
	{
		TranslationUnit translationUnit;
		Output output_;

		string outputFile;
        string inputFilename;
        File inputFile;
	}
	
	this (string inputFilename, TranslationUnit translationUnit, string outputFile)
	{
		this.translationUnit = translationUnit;
		this.outputFile = outputFile;
        this.inputFilename = inputFilename;
        inputFile = translationUnit.file(inputFilename);

		output_ = new Output;
	}
	
	@property Output output ()
	{
		return output_;
	}
	
	void convert ()
	{
		foreach (cursor, parent ; translationUnit.declarations)
		{
		    if (skipDeclaration(cursor))
		        continue;
		    
			with (CXCursorKind)
				switch (cursor.kind)
				{
					case CXCursor_ObjCInterfaceDecl:
						(new ObjcInterface(cursor, parent, this)).convert;
					break;
					
					case CXCursor_VarDecl:
						output.variables ~= variable(cursor, new String);
					break;
					
					case CXCursor_FunctionDecl:
					{
						auto f = new String;
						auto name = convertIdentifier(cursor.spelling);
						convertFunction(cursor.func, name, f);
						f ~= ";";
						output.functions ~= f;
					}
					break;
					
					case CXCursor_TypedefDecl:
						output.typedefs ~= typedef_(cursor, new String);
					break;
					
					case CXCursor_StructDecl: (new Struct(cursor, parent, this)).convert; break;
					
					default: continue;
				}
		}

		write(outputFile, output.toString);
	}
	
	String variable (Cursor cursor, String context = output)
	{
		context ~= convertType(cursor.type);
		context ~= " " ~ convertIdentifier(cursor.spelling);
		context ~= ";";
		
		return context;
	}
	
	String typedef_ (Cursor cursor, String context = output)
	{
		context ~= "alias ";
		context ~= convertType(cursor.type.canonicalType);
		context ~= " " ~ cursor.spelling;
		context ~= ";";
		
		return context;
	}
	
private

    bool skipDeclaration (Cursor cursor)
    {
        return inputFile != cursor.location.spelling.file;
    }
}

String convertFunction (FunctionCursor func, string name, String context, bool isStatic = false)
{
	if (isStatic)
		context ~= "static ";
		
	Parameter[] params;
	params.reserve(func.type.func.arguments.length);
	
	foreach (param ; func.parameters)
	{
		auto type = convertType(param.type);
		auto spelling = param.spelling;
		
		params ~= Parameter(type, spelling);
	}
	
	auto resultType = convertType(func.resultType);

	return convertFunction(resultType, name, params, func.isVariadic, context);
}

package struct Parameter
{
	string type;
	string name;
}

package String convertFunction (string result, string name, Parameter[] parameters, bool variadic, String context)
{
	context ~= result;
	context ~= ' ';
	context ~= name ~ " (";

	string[] params;
	
	foreach (param ; parameters)
	{
		params ~= param.type;

		if (param.name.any)
			params[$ - 1] ~= " " ~ param.name;
	}
	
	context ~= params.join(", ");

	if (variadic)
	{
		if (parameters.any)
			context ~= ", ";

		context ~= "...";
	}
	
	context ~= ')';
	
	return context;
}

string convertIdentifier (string str)
{
	return isDKeyword(str) ? str ~ '_' : str;
}

bool isDKeyword (string str)
{
	switch (str)
	{
		case "abstract":
		case "alias":
		case "align":
		case "asm":
		case "assert":
		case "auto":

		case "body":
		case "bool":
		case "break":
		case "byte":

		case "case":
		case "cast":
		case "catch":
		case "cdouble":
		case "cent":
		case "cfloat":
		case "char":
		case "class":
		case "const":
		case "continue":
		case "creal":

		case "dchar":
		case "debug":
		case "default":
		case "delegate":
		case "delete":
		case "deprecated":
		case "do":
		case "double":

		case "else":
		case "enum":
		case "export":
		case "extern":

		case "false":
		case "final":
		case "finally":
		case "float":
		case "for":
		case "foreach":
		case "foreach_reverse":
		case "function":

		case "goto":

		case "idouble":
		case "if":
		case "ifloat":
		case "import":
		case "in":
		case "inout":
		case "int":
		case "interface":
		case "invariant":
		case "ireal":
		case "is":

		case "lazy":
		case "long":

		case "macro":
		case "mixin":
		case "module":

		case "new":
		case "nothrow":
		case "null":

		case "out":
		case "override":

		case "package":
		case "pragma":
		case "private":
		case "protected":
		case "public":
		case "pure":

		case "real":
		case "ref":
		case "return":

		case "scope":
		case "shared":
		case "short":
		case "static":
		case "struct":
		case "super":
		case "switch":
		case "synchronized":

		case "template":
		case "this":
		case "throw":
		case "true":
		case "try":
		case "typedef":
		case "typeid":
		case "typeof":

		case "ubyte":
		case "ucent":
		case "uint":
		case "ulong":
		case "union":
		case "unittest":
		case "ushort":

		case "version":
		case "void":
		case "volatile":

		case "wchar":
		case "while":
		case "with":

		case "__FILE__":
		case "__LINE__":
		case "__DATE__":
		case "__TIME__":
		case "__TIMESTAMP__":
		case "__VENDOR__":
		case "__VERSION__":
			return true;

		default: break;
	}

	if (true /*D2*/)
	{
		switch (str)
		{
			case "immutable":
			case "nothrow":
			case "pure":
			case "shared":

			case "__gshared":
			case "__thread":
			case "__traits":

			case "__EOF__":
				return true;

			default: return str.any && str.first == '@';
		}
	}
	
	return false;
}