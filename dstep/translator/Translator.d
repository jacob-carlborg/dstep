/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Translator;

import std.file;

import mambo.core.io;
import mambo.core.string;

import clang.c.index;
import clang.Cursor;
import clang.File;
import clang.TranslationUnit;
import clang.Util;

import dstep.translator.Declaration;
import dstep.translator.Enum;
import dstep.translator.objc.ObjcInterface;
import dstep.translator.Output;
import dstep.translator.Struct;
import dstep.translator.Type;
import dstep.translator.Union;

class Translator
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
	
	void translate ()
	{
		foreach (cursor, parent ; translationUnit.declarations)
		{
		    if (skipDeclaration(cursor))
		        continue;

			auto code = translate(cursor, parent);
			
			with (CXCursorKind)
				switch (cursor.kind)
				{
					case CXCursor_ObjCInterfaceDecl: output.classes ~= code; break;
					case CXCursor_StructDecl: output.structs ~= code; break;
					case CXCursor_EnumDecl: output.enums ~= code; break;
					case CXCursor_UnionDecl: output.unions ~= code; break;
					case CXCursor_VarDecl: output.variables ~= code; break;
					case CXCursor_FunctionDecl: output.functions ~= code; break;
					case CXCursor_TypedefDecl: output.typedefs ~= code; break;

					default: continue;
				}
		}

		auto data = output.toString;
		write(outputFile, data);
		println(data);
	}
	
	string translate (Cursor cursor, Cursor parent = Cursor.empty)
	{
		with (CXCursorKind)
			switch (cursor.kind)
			{
				case CXCursor_ObjCInterfaceDecl:
					return (new ObjcInterface(cursor, parent, this)).translate;
				break;
			
				case CXCursor_VarDecl:
					return variable(cursor, new String);
				break;
			
				case CXCursor_FunctionDecl:
				{
					auto name = translateIdentifier(cursor.spelling);
					return translateFunction(cursor.func, name, new String) ~ ";";
				}
				break;
			
				case CXCursor_TypedefDecl:
					return typedef_(cursor, new String);
				break;
			
				case CXCursor_StructDecl: return (new Struct(cursor, parent, this)).translate; break;
				case CXCursor_EnumDecl: return (new Enum(cursor, parent, this)).translate; break;
				case CXCursor_UnionDecl: return (new Union(cursor, parent, this)).translate; break;
			
				default:
					assert(0, `Translator.translate: missing implementation for "` ~ cursor.kind.toString ~ `".`);
			}
	}
	
	string variable (Cursor cursor, String context = output)
	{
		context ~= translateType(cursor.type);
		context ~= " " ~ translateIdentifier(cursor.spelling);
		context ~= ";";
		
		return context.data;
	}
	
	string typedef_ (Cursor cursor, String context = output)
	{
		context ~= "alias ";
		context ~= translateType(cursor.type.canonicalType);
		context ~= " " ~ cursor.spelling;
		context ~= ";";
		
		return context.data;
	}
	
private

    bool skipDeclaration (Cursor cursor)
    {
        return inputFile != cursor.location.spelling.file;
    }
}

string translateFunction (FunctionCursor func, string name, String context, bool isStatic = false)
{
	if (isStatic)
		context ~= "static ";
		
	Parameter[] params;

	if (func.type.isValid) // This will be invalid of Objective-C methods
		params.reserve(func.type.func.arguments.length);
	
	foreach (param ; func.parameters)
	{
		auto type = translateType(param.type);
		params ~= Parameter(type, param.spelling);
	}
	
	auto resultType = translateType(func.resultType);

	return translateFunction(resultType, name, params, func.isVariadic, context);
}

package struct Parameter
{
	string type;
	string name;
	bool isConst;
}

package string translateFunction (string result, string name, Parameter[] parameters, bool variadic, String context)
{
	context ~= result;
	context ~= ' ';
	context ~= name ~ " (";

	string[] params;
	
	foreach (param ; parameters)
	{
		string p;

		if (param.isConst)
			p ~= "const(";

		p ~= param.type;
		
		if (param.isConst)
			p ~= ')';

		if (param.name.any)
			p ~= " " ~ param.name;
		
		params ~= p;
	}
	
	context ~= params.join(", ");

	if (variadic)
	{
		if (parameters.any)
			context ~= ", ";

		context ~= "...";
	}
	
	context ~= ')';
	
	return context.data;
}

string translateIdentifier (string str)
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