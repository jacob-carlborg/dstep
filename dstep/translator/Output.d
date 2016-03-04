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

import dstep.translator.CodeBlock;
import dstep.translator.IncludeHandler;
import dstep.translator.Type;

Output output;

static this ()
{
    output = new Output;
}

void resetOutput()
{
    output = new Output;
}

class Output
{
    String currentContext;

    alias currentContext this;

    string externDeclaration;

    ClassData currentClass;
    ClassData currentInterface;

    this ()
    {
        currentContext = new String;

        currentClass = new ClassData;
        currentInterface = new ClassData;
    }

    @property string data (string extraDeclarations = "")
    {
        newContext();

        addDeclarations(includeHandler.toImports(), false);

        if (externDeclaration.isPresent)
        {
            this ~= externDeclaration;
            currentContext.put(nl, nl);
        }

        this ~= extraDeclarations;

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

    override string toString ()
    {
        return toString("");
    }

    string toString (string extraDeclarations)
    {
        return data(extraDeclarations).strip('\n');
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

    CodeBlock[] instanceVariables;

    bool isFwdDeclaration;

    @property CodeBlock data ()
    {
        import std.format : format;

        if (name.isPresent)
            name = ' ' ~ name;

        if (isFwdDeclaration)
        {
            isFwdDeclaration = true;
            return CodeBlock("%s%s;".format(type, name));
        }
        else
        {
            CodeBlock result = CodeBlock(
                "%s%s".format(type, name),
                EndlHint.subscopeStrong);

            addDeclarations(result, instanceVariables);

            return result;
        }
    }

protected:

    @property string type ()
    {
        return "struct";
    }

    void addDeclarations (ref CodeBlock result, CodeBlock[] declarations)
    {
        foreach (i, e ; declarations)
            result.children ~= e;
    }
}

class EnumData : StructData
{
    @property override string type ()
    {
        return "enum";
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
    CodeBlock[] members;

    string name;
    string superclass;
    string[] interfaces;

    HashSet!(string) propertyList;

    private bool[string] mangledMethods;

    this ()
    {
        propertyList = new HashSet!(string);
    }

    string getMethodName (FunctionCursor func, string name = "", bool translateIdentifier = true)
    {
        auto mangledName = mangle(func, name);
        auto selector = func.spelling;

        if (!(mangledName in mangledMethods))
        {
            mangledMethods[mangledName] = true;
            name = name.isBlank ? selector : name;
            return translateSelector(name, false, translateIdentifier);
        }

        return translateSelector(name, true, translateIdentifier);
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

    @property override CodeBlock data ()
    {
        import std.format;
        import std.array;

        auto header = appender!string("%s %s".format(type, name));

        if (superclass.any)
        {
            header.put(" : ");
            header.put(superclass);
        }

        writeInterfaces(header);

        auto result = CodeBlock(header.data, EndlHint.subscopeStrong);

        writeMembers(result);

        return result;
    }

    override protected @property string type ()
    {
        return "class";
    }

private:

    void writeInterfaces (ref Appender!string header)
    {
        if (interfaces.any)
        {
            if (superclass.isEmpty)
                header.put(" : ");

            foreach (i, s ; interfaces)
            {
                if (i != 0)
                    header.put(", ");

                header.put(s);
            }
        }
    }

    void writeMembers (ref CodeBlock cls)
    {
        addDeclarations(cls, members);
    }
}

class InterfaceData : ClassData
{
    protected @property override string type ()
    {
        return "interface";
    }
}

class ClassExtensionData : ClassData
{
    protected @property override string type ()
    {
        return "__classext";
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
            appender.put("    ");
    }
}

struct NewLine {}
NewLine nl;
