/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Output;

static import std.array;

import tango.util.container.HashSet;

import mambo.core._;

import clang.Cursor;
import dstep.translator.IncludeHandler;
import dstep.translator.Type;

Output output;

static this ()
{
	output = new Output;
}

class Output
{
	String currentContext;
	
	alias currentContext this;
	
	String before;
	String after;
	String imports;
	string externDeclaration;

	string[] typedefs;	
	string[] variables;
	
	string[] classes;
	string[] interfaces;
	string[] structs;
	string[] enums;
	string[] unions;
	string[] functions;
	
	ClassData currentClass;
	ClassData currentInterface;
	
	this ()
	{
		before = new String;
		after = new String;
		imports = new String;
		currentContext = new String;
		
		currentClass = new ClassData;
		currentInterface = new ClassData;
	}
	
	@property string data ()
	{
		newContext();

		this ~= before.data;
		addDeclarations(includeHandler.toImports(), false);
		this ~= imports.data;
		
		if (imports.any)
		    this ~= nl;
		
		if (externDeclaration.isPresent)
		{
			this ~= externDeclaration;
			currentContext.put(nl, nl);
		}

		addDeclarations(typedefs, false);
		addDeclarations(variables, false);
		addDeclarations(enums);
		addDeclarations(structs);
		addDeclarations(unions);
		addDeclarations(classes);
		addDeclarations(interfaces);
		addDeclarations(functions, false);

		this ~= after.data;
		
		return currentContext.data;
	}
	
	/**
	 * Creates a new context and sets it as the current context. Returns the newly created
	 * context.
	 */ 
	String newContext ()
	{
		auto context = new String;
		context.indentationLevel = currentContext.indentationLevel;
		return currentContext = context;
	}
	
	string toString ()
	{
		return data.strip('\n');
	}

private:

    void addDeclarations (string[] declarations, bool extraNewline = true)
    {
		auto newline = "\n";
		
		if (extraNewline)
			newline ~= "\n";
		
        this ~= declarations.join(newline);

        if (declarations.any)
            this ~= "\n\n";
    }
}

class StructData
{
	string name;

	string[] instanceVariables;
	
	@property string data ()
	{
		auto context = output.newContext();

		if (name.isPresent)
			name = ' ' ~ name;

		context.put(type, name, nl, '{', nl);

		context.indent in {
			addDeclarations(context, instanceVariables);
		};
		
		auto str = context.data.strip('\n');
		context = output.newContext();
		context ~= str;
		context.put(nl, '}');

		return context.data;
	}
	
protected:
	
	@property string type ()
	{
		return "struct";
	}

	void addDeclarations (String context, string[] declarations)
    {
		foreach (i, e ; declarations)
		{
			if (i != 0)
				context ~= nl;

			context ~= e;
		}

        if (declarations.any)
		{
			context ~= nl;
			context ~= nl;
		}
    }
}

class EnumData : StructData
{
	@property override string type ()
	{
		return "enum";
	}
	
protected:

	override void addDeclarations (String context, string[] declarations)
    {
		foreach (i, e ; declarations)
		{
			if (i != 0)
			{
				context ~= ",";
				context ~= nl;
			}

			context ~= e;
		}

        if (declarations.any)
		{
			context ~= nl;
			context ~= nl;
		}
    }
}

class UnionData : StructData
{
	@property override string type ()
	{
		return "union";
	}
}

class ClassData : StructData
{
	string[] instanceMethods;
	string[] staticMethods;
	string[] properties;
	
	string[] staticVariables;
	
	string name;
	string[] interfaces;
	string superclass;

	HashSet!(string) propertyList;

	private bool[string] mangledMethods;

	this ()
	{
		propertyList = new HashSet!(string);
	}

	string getMethodName (FunctionCursor func, string name = "")
	{
		auto mangledName = mangle(func, name);
		auto selector = func.spelling;
		
		if (!(mangledName in mangledMethods))
		{
			mangledMethods[mangledName] = true;
			name = name.isBlank ? selector : name;
			return translateSelector(name);
		}
		
		return translateSelector(name, true);
	}
	
	private string mangle (FunctionCursor func, string name)
	{
		auto selector = func.spelling;
		name = name.isBlank ? translateSelector(selector) : name;
		auto mangledName = name;
		
		foreach (param ; func.parameters)
			mangledName ~= "_" ~ translateType(param.type);
			
		return mangledName;
	}
	
	@property override string data ()
	{
		auto cls = output.newContext();
		
		cls.put("class ", name, nl, '{', nl);
		
		cls.indent in {
			addDeclarations(cls, properties);
			addDeclarations(cls, staticVariables);
			addDeclarations(cls, instanceVariables);
			addDeclarations(cls, staticMethods);
			addDeclarations(cls, instanceMethods);
		};
		
		auto context = output.newContext();
		context ~= cls.data.strip('\n');
		context.put(nl, '}');

		return context.data;
	}
}

class String
{
	int indentationLevel;

	private
	{
		std.array.Appender!(string) appender;
		int prevIndendationLevel;
		bool shouldIndent;
	}
	
	String opOpAssign (string op, T) (T t) if (op == "~" && !is(T == NewLine))
	{
		return put(t);
	}
	
	String opOpAssign (string op) (NewLine) if (op == "~")
	{
		return put(nl);
	}
	
	String put (Args...) (Args args)// if (!is(T == NewLine))
	{
		foreach (arg ; args)
		{
			static if (is(typeof(arg) == NewLine))
				put(nl);
				
			else
			{
				if (shouldIndent)
				{
					_indent();
					shouldIndent = false;
				}

				appender.put(arg);
			}
		}

		return this;
	}
	
	String put () (NewLine)
	{
		appender.put('\n');
		shouldIndent = indentationLevel > 0;
		
		return this;
	}
	
	alias put append;

	String appendnl (T) (T t)
	{
		put(t);
		return put(nl);
	}
	
	@property string data ()
	{
		return appender.data;
	}
	
	@property bool isEmpty ()
	{
		return appender.data.isEmpty;
	}
	
	Indendation indent ()
	{
		return indent(indentationLevel + 1);
	}
	
	Indendation indent (int indentationLevel)
	{
		prevIndendationLevel = this.indentationLevel;
		this.indentationLevel = indentationLevel;
		return Indendation(this);
	}
	
	static struct Indendation
	{
		private String str;
		
		void opIn (void delegate () dg)
		{
			str.shouldIndent = str.indentationLevel > 0;
			dg();
			output.currentContext = str;
			str.indentationLevel = str.prevIndendationLevel;
		}
	}
	
private:
	
	void _indent ()
	{
		foreach (i ; 0 .. indentationLevel)
			appender.put('\t');
	}
}

struct NewLine {}
NewLine nl;