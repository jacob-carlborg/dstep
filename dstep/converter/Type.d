/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 30, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.Type;

import std.string;

import mambo.core.string;

import clang.c.index;
import clang.Type;
import mambo.core.io;
string convertType (string str)
{
	switch (str)
	{
		case "long": return "c_long";
		case "BOOL": return "bool";
		case "unsigned":
		case "unsigned int": return "uint";
		default: return str;
	}
}

string convertType (Type type, bool rewriteIdToObject = true)
{
	with (CXTypeKind)
	{
		if (type.kind == CXType_BlockPointer || type.isFunctionPointerType)
			return convertFunctionPointerType(type);
			
		if (type.kind == CXType_ObjCObjectPointer && !type.isObjCBuiltinType)
			return convertObjCObjectPointerType(type);
			
		if (type.isWideCharType)	
			return "wchar";

		switch (type.kind)
		{
			case CXType_Pointer: return convertType(type.pointee) ~ "*";
			case CXType_Bool: return "bool";
			case CXType_ObjCId: return rewriteIdToObject ? "Object" : "id";
			default: return convertType(type.spelling);
		}
	}
}

string convertFunctionPointerType (Type type)
{
	return "<unimplemented>";
}

string convertObjCObjectPointerType (Type type)
{
	return "<unimplemented>";
}

string convertSelector (string str, bool fullName = false)
{
	if (fullName)
		str = str.replace(":", "_");
		
	else
		str = str.chomp(":");
		
	return convertIdentifier(str);
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
}