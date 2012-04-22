/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.converter.Output;

import mambo.core._;

import clang.Cursor;
import dstep.converter.Type;

class Output : String
{
	String before;
	String after;
	String imports;
	String[] functions;
	
	String[] variables;
	
	Class[] classes;
	Class[] interfaces;
	
	Class currentClass;
	Class currentInterface;
	
	this ()
	{
		before = new String;
		after = new String;
		imports = new String;
		
		currentClass = new Class;
		currentInterface = new Class;
	}
	
	@property string data ()
	{
		this ~= before.data;
		this ~= imports.data;
		
		if (imports.any)
		    this ~= nl;
		
		addDeclarations(variables);
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
    
    void addDeclarations (Class[] declarations)
    {
        this ~= declarations.map!(e => e.data).join("\n");
        
        if (declarations.any)
            this ~= "\n\n";
    }
}

class Class
{
	String[] instanceMethods;
	String[] staticMethods;
	
	String[] instanceVariables;
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
			return convertSelector(name);
		}
		
		return convertSelector(name, true);
	}
	
	private string mangle (FunctionCursor func, string name)
	{
		auto selector = func.spelling;
		name = name.isBlank ? convertSelector(selector) : name;
		auto mangledName = name;
		
		foreach (param ; func.parameters)
			mangledName ~= "_" ~ convertType(param.type);
			
		return mangledName;
	}
	
	@property string data ()
	{
		auto cls = new String;
		
		void appendData (String[] data, String[] next = null)
		{
			auto newData = join(map!(e => e.data)(data), "\n\t");
			cls ~= newData;

			if (newData.isPresent && next.isPresent)
			{
				cls ~= nl;
				cls ~= nl;
			}
		}
		
		cls.put("class ", name, nl, '{', nl);
		
		cls.indent in {
			appendData(staticVariables, instanceVariables);
			appendData(instanceVariables, staticMethods);
			appendData(staticMethods, instanceMethods);
			appendData(instanceMethods);
		};
		
		cls ~= "\n}";
		
		return cls.data;
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
				appender.put('\n');
				
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