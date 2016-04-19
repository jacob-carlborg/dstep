/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Output;

import std.array;

import tango.util.container.HashSet;

import mambo.core._;

import clang.Cursor;

import dstep.translator.Context;
import dstep.translator.IncludeHandler;
import dstep.translator.Type;

class Output
{
    private Appender!string buffer;
    private Entity[] stack;
    private Entity first = Entity.bottom;
    private Appender!(char[]) weak;

    this()
    {
        stack ~= Entity.bottom;

        // There is bug in Phobos, formattedWrite will not write anything
        // to the output range if put was not invoked before.
        buffer.put("");
        weak.put("");
    }

    public bool empty()
    {
        return stack.length == 1 && stack.back == Entity.bottom;
    }

    public void separator()
    {
        if (stack.back == Entity.singleLine)
            stack.back = Entity.separator;
    }

    public void output(Output output)
    {
        if (output.stack.length == 1 && output.stack.back == Entity.singleLine)
            singleLine(output.data());
        else
        {
            import std.string : splitLines, KeepTerminator;

            if (output.stack.back != Entity.bottom)
                flush();

            if (stack.back != Entity.bottom &&
                output.stack.back != Entity.bottom)
                buffer.put("\n");

            if (stack.back != Entity.bottom &&
                output.first != Entity.bottom &&
                (stack.back != Entity.singleLine ||
                output.first != Entity.singleLine))
                buffer.put("\n");

            foreach (line; output.data().splitLines(KeepTerminator.yes))
            {
                indent();
                buffer.put(line);
            }

            stack.popBack();
            stack ~= output.stack;

            if (first == Entity.bottom)
                first = output.first;
        }
    }

    public void append(Char, Args...)(in Char[] fmt, Args args)
    {
        import std.format;

        if (stack.back != Entity.singleLine)
            singleLine(fmt, args);
        else if (weak.data.empty)
            formattedWrite(buffer, fmt, args);
        else
            formattedWrite(weak, fmt, args);
    }

    private void singleLineImpl(Char, Args...)(in Char[] fmt, Args args)
    {
        import std.format;

        indent();
        formattedWrite(buffer, fmt, args);
        stack.back = Entity.singleLine;

        if (first == Entity.bottom)
            first = Entity.singleLine;
    }

    public void singleLine(Char, Args...)(in Char[] fmt, Args args)
    {
        import std.format;

        if (stack.length > 1 &&
            stack.back == Entity.bottom &&
            stack[$ - 2] == Entity.subscopeWeak)
        {
            formattedWrite(weak, fmt, args);
            stack.back = Entity.singleLine;
        }
        else
        {
            flush();

            if (stack.back != Entity.singleLine && stack.back != Entity.bottom)
                buffer.put("\n");

            if (stack.back != Entity.bottom)
                buffer.put("\n");

            singleLineImpl(fmt, args);
        }
    }

    public Indent multiLine(Char, Args...)(in Char[] fmt, Args args)
    {
        import std.format;

        flush();

        if (stack.back != Entity.bottom)
            buffer.put("\n\n");

        indent();
        formattedWrite(buffer, fmt, args);
        buffer.put("\n");
        stack.back = Entity.multiLine;
        stack ~= Entity.bottom;

        if (first == Entity.bottom)
            first = Entity.multiLine;

        return Indent(this);
    }

    public Indent subscopeStrong(Char, Args...)(in Char[] fmt, Args args)
    {
        import std.format;

        flush();

        if (stack.back != Entity.bottom)
            buffer.put("\n\n");

        indent();
        formattedWrite(buffer, fmt, args);
        buffer.put("\n");
        indent();
        buffer.put("{\n");
        stack.back = Entity.subscopeStrong;
        stack ~= Entity.bottom;

        if (first == Entity.bottom)
            first = Entity.subscopeStrong;

        return Indent(this, "}");
    }

    public Indent subscopeWeak(Char, Args...)(in Char[] fmt, Args args)
    {
        import std.format;

        flush();

        if (stack.back != Entity.bottom)
            buffer.put("\n\n");

        indent();
        formattedWrite(buffer, fmt, args);
        buffer.put("\n");
        stack.back = Entity.subscopeWeak;
        stack ~= Entity.bottom;

        if (first == Entity.bottom)
            first = Entity.subscopeWeak;

        return Indent(this, "}");
    }

    public string data(string suffix = "")
    {
        if (!suffix.empty)
            return buffer.data() ~ suffix;
        else
            return buffer.data();
    }

    struct Indent
    {
        private Output output;
        private string sentinel;

        ~this()
        {
            bool flushed = output.flush(false);

            auto back = output.stack.back;
            output.stack.popBack();

            if (!sentinel.empty && !flushed)
            {
                if (back != Entity.bottom)
                    output.buffer.put("\n");

                output.indent();
                output.buffer.put(sentinel);
            }
        }

        void opIn (void delegate () nested)
        {
            nested();
        }
    }

    private enum Entity
    {
        bottom,
        separator,
        singleLine,
        multiLine,
        subscopeWeak,
        subscopeStrong,
    }

    private bool flush(bool brace = true)
    {
        if (!weak.data.empty)
        {
            string weak = this.weak.data.idup;
            this.weak.clear();

            if (brace)
            {
                indent(-1);
                buffer.put("{\n");
            }

            stack.back = Entity.singleLine;
            singleLineImpl(weak);
            weak = null;

            return true;
        }
        else if (stack.length > 1 &&
            stack[$ - 2] == Entity.subscopeWeak &&
            stack.back == Entity.bottom &&
            brace)
        {
            indent(-1);
            buffer.put("{\n");
        }

        return false;
    }

    private void indent()
    {
        foreach (x; 0..stack.length - 1)
            buffer.put("    ");
    }

    private void indent(int shift)
    {
        foreach (x; 0..stack.length - 1 + shift)
            buffer.put("    ");
    }
}

class StructData
{
    string name;
    protected Context context;

    Output[] instanceVariables;

    bool isFwdDeclaration;

    this(Context context)
    {
        this.context = context;
    }

    @property Output data ()
    {
        import std.format : format;

        Output output = new Output();

        if (name.isPresent)
            name = ' ' ~ name;

        if (isFwdDeclaration)
        {
            isFwdDeclaration = true;
            output.singleLine("%s%s;", type, name);
            return output;
        }
        else
        {
            output.subscopeStrong("%s%s", type, name) in {
                addDeclarations(output, instanceVariables);
            };

            return output;
        }
    }

protected:

    @property string type ()
    {
        return "struct";
    }

    void addDeclarations (Output output, Output[] declarations)
    {
        foreach (i, e ; declarations)
            output.output(e);
    }
}

class UnionData : StructData
{
    this(Context context)
    {
        super(context);
    }

    @property override string type ()
    {
        return "union";
    }
}

class ClassData : StructData
{
    Output[] members;

    string name;
    string superclass;
    string[] interfaces;

    HashSet!(string) propertyList;

    private bool[string] mangledMethods;

    this (Context context)
    {
        super(context);
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
            mangledName ~= "_" ~ translateType(context, param);

        return mangledName;
    }

    @property override Output data ()
    {
        import std.format;
        import std.array;

        auto header = appender!string();

        formattedWrite(
            header,
            "%s %s",
            type,
            name);

        if (superclass.any)
        {
            header.put(" : ");
            header.put(superclass);
        }

        writeInterfaces(header);

        Output output = new Output();

        output.subscopeStrong(header.data) in {
            writeMembers(output);
        };

        return output;
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

    void writeMembers (Output output)
    {
        addDeclarations(output, members);
    }
}

class InterfaceData : ClassData
{
    this(Context context)
    {
        super(context);
    }

    protected @property override string type ()
    {
        return "interface";
    }
}

class ClassExtensionData : ClassData
{
    this(Context context)
    {
        super(context);
    }

    protected @property override string type ()
    {
        return "__classext";
    }
}
