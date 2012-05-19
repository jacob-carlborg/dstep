/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Output;

import mambo.core._;

import clang.Cursor;
import dstep.translator.Type;

class Output : String
{
	String before;
	String after;
	String imports;
	String[] functions;
	
	String[] variables;
	String[] typedefs;
	
	ClassData[] classes;
	ClassData[] interfaces;
	StructData[] structs;
	StructData[] unions;
	
	ClassData currentClass;
	ClassData currentInterface;
	
	this ()
	{
		before = new String;
		after = new String;
		imports = new String;
		
		currentClass = new ClassData;
		currentInterface = new ClassData;
	}
	
	@property string data ()
	{
		this ~= before.data;
		this ~= imports.data;
		
		if (imports.any)
		    this ~= nl;
		
		addDeclarations(typedefs);
		addDeclarations(variables);
		addDeclarations(structs);
		addDeclarations(unions);
		addDeclarations(classes);
		addDeclarations(interfaces);
		addDeclarations(functions);

		this ~= after.data;
		
		return super.data;
	}
	
	string toString ()
	{
		return data.strip('\n');
	}

private:

    void addDeclarations (String[] declarations)
    {
        this ~= declarations.map!(e => e.data).join("\n");
        
        if (declarations.any)
            this ~= "\n\n";
    }

    void addDeclarations (StructData[] declarations)
    {
        this ~= declarations.map!(e => e.data).join("\n\n");
        
        if (declarations.any)
            this ~= "\n\n";
    }

    void addDeclarations (ClassData[] declarations)
    {
        this ~= declarations.map!(e => e.data).join("\n\n");
        
        if (declarations.any)
            this ~= "\n\n";
    }
}

class StructData
{
	string name;

	String[] instanceVariables;
	
	@property string data ()
	{
		auto context = new String;
		
		context.put(type, ' ', name, nl, '{', nl);
		
		context.indent in {
			addDeclarations(context, instanceVariables);
		};
		
		return context.data.strip('\n') ~ "\n}";
	}
	
protected:
	
	@property string type ()
	{
		return "struct";
	}

	void addDeclarations (String context, String[] declarations)
    {
		foreach (i, e ; declarations)
		{
			if (i != 0)
				context ~= nl;

			context ~= e.data;
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

	override void addDeclarations (String context, String[] declarations)
    {
		foreach (i, e ; declarations)
		{
			if (i != 0)
			{
				context ~= ",";
				context ~= nl;
			}

			context ~= e.data;
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
	String[] instanceMethods;
	String[] staticMethods;
	
	String[] staticVariables;
	
	string name;
	string[] interfaces;
	string superclass;
	
	private bool[string] mangledMethods;
	
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
		auto cls = new String;
		
		cls.put("class ", name, nl, '{', nl);
		
		cls.indent in {
			addDeclarations(cls, staticVariables);
			addDeclarations(cls, instanceVariables);
			addDeclarations(cls, staticMethods);
			addDeclarations(cls, instanceMethods);
		};
		
		return cls.data.strip('\n') ~ "\n}";
	}
}

class String
{
	private
	{
		std.array.Appender!(string) appender;
		ubyte indendationLevel;
		ubyte prevIndendationLevel;
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
		if (shouldIndent)
		{
			_indent();
			shouldIndent = false;
		}

		foreach (arg ; args)
		{
			static if (is(typeof(arg) == NewLine))
				put(nl);
				
			else
				appender.put(arg);
		}

		return this;
	}
	
	String put () (NewLine)
	{
		appender.put('\n');
		shouldIndent = indendationLevel > 0;
		
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
		return indent(1);
	}
	
	Indendation indent (ubyte indendationLevel)
	{
		prevIndendationLevel = this.indendationLevel;
		this.indendationLevel = indendationLevel;
		return Indendation(this);
	}
	
	static struct Indendation
	{
		private String str;
		
		void opIn (void delegate () dg)
		{
			str._indent;
			dg();
			str.indendationLevel = str.prevIndendationLevel;
		}
	}
	
private:
	
	void _indent ()
	{
		foreach (i ; 0 .. indendationLevel)
			appender.put('\t');
	}
}

struct NewLine {}
NewLine nl;