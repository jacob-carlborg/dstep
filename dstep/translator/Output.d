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
import clang.SourceLocation;
import clang.SourceRange;

import dstep.translator.CommentIndex;
import dstep.translator.Context;
import dstep.translator.IncludeHandler;
import dstep.translator.Type;

class Output
{
    private enum Entity
    {
        bottom,
        separator,
        comment,
        singleLine,
        multiLine,
        subscopeWeak,
        subscopeStrong,
    }

    private Appender!string buffer;
    private Entity[] stack;
    private Entity first = Entity.bottom;
    private Appender!(char[]) weak;
    private CommentIndex commentIndex = null;
    private uint lastestOffset = 0;
    private uint lastestLine = 0;
    private uint headerEndOffset = 0;

    this(Output parent)
    {
        stack ~= Entity.bottom;

        // There is bug in Phobos, formattedWrite will not write anything
        // to the output range if put was not invoked before.
        buffer.put("");
        weak.put("");
        commentIndex = parent.commentIndex;
        lastestOffset = parent.lastestOffset;
        lastestLine = parent.lastestLine;
    }

    this(CommentIndex commentIndex = null)
    {
        stack ~= Entity.bottom;

        // There is bug in Phobos, formattedWrite will not write anything
        // to the output range if put was not invoked before.
        buffer.put("");
        weak.put("");
        this.commentIndex = commentIndex;
    }

    public bool empty()
    {
        return stack.length == 1 && stack.back == Entity.bottom;
    }

    public void separator()
    {
        if (stack.back == Entity.singleLine ||
            stack.back == Entity.comment)
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

            import std.algorithm.comparison;

            lastestOffset = max(lastestOffset, output.lastestOffset);
            lastestLine = max(lastestLine, output.lastestLine);
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
            // We are on the first line of weak sub-scope.
            // Save the line for later handling.
            formattedWrite(weak, fmt, args);
            stack.back = Entity.singleLine;
        }
        else
        {
            flush();

            if (stack.back != Entity.singleLine &&
                stack.back != Entity.bottom &&
                stack.back != Entity.comment)
                buffer.put("\n");

            if (stack.back != Entity.bottom)
                buffer.put("\n");

            singleLineImpl(fmt, args);
        }
    }

    public void singleLine(Char, Args...)(
        in SourceRange extent,
        in Char[] fmt,
        Args args)
    {
        flushLocation(extent);
        singleLine(fmt, args);
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

    private void subscopeStrongImpl(Char, Args...)(
        in Char[] fmt,
        Args args)
    {
        import std.format;

        flush();

        if (stack.back == Entity.comment)
            buffer.put("\n");
        else if (stack.back != Entity.bottom)
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
    }

    public Indent subscopeStrong(Char, Args...)(
        in Char[] fmt,
        Args args)
    {
        subscopeStrongImpl!(Char, Args)(fmt, args);
        return Indent(this, "}");
    }

    public Indent subscopeStrong(Char, Args...)(
        in SourceRange extent,
        in Char[] fmt,
        Args args)
    {
        SourceLocation start = extent.start;
        SourceLocation end = extent.end;

        flushLocationBegin(start.line, start.column, start.offset);
        subscopeStrongImpl(fmt, args);
        return Indent(this, "}", end.line, end.column, end.offset);
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

    private void comment(CommentIndex.Comment comment)
    {
        import std.format;

        if (lastestLine == comment.line)
        {
            buffer.put(" ");
        }
        else if (stack.back != Entity.bottom)
        {
            if (lastestLine + 1 < comment.line ||
                (stack.back != Entity.singleLine &&
                stack.back != Entity.comment))
                buffer.put('\n');

            buffer.put('\n');
        }

        import std.string;

        auto lines = lineSplitter!(KeepTerminator.yes)(comment.content);

        if (!lines.empty)
        {
            if (lastestLine != comment.line)
                indent();

            formattedWrite(buffer, lines.front);
            lines.popFront;

            foreach (line; lines)
            {
                indent();
                formattedWrite(buffer, line);
            }
        }

        stack.back = Entity.comment;

        if (first == Entity.bottom)
            first = Entity.comment;

        lastestLine = comment.extent.end.line;
        lastestOffset = comment.extent.end.offset;
    }

    public void flushLocation(uint offset)
    {
        flushComments(offset);
    }

    private void flushComments(uint offset)
    {
        if (commentIndex)
        {
            auto comments = commentIndex.queryComments(lastestOffset, offset);

            foreach (c; comments)
                comment(c);

            lastestOffset = offset;
        }
    }

    public void finalize()
    {
        if (!buffer.data.empty)
        {
            buffer.put("\n");

            if (stack.back != Entity.singleLine &&
                stack.back != Entity.comment)
                buffer.put("\n");
        }
    }

    private void flushLocationBegin(
        uint beginLine,
        uint beginColumn,
        uint beginOffset,
        bool separate = true)
    {
        flushComments(beginOffset);

        if (separate && lastestLine + 1 < beginLine)
            separator();
    }

    private void flushLocationEnd(
        uint endLine,
        uint endColumn,
        uint endOffset)
    {
        flushComments(endOffset);

        lastestLine = endLine;
        lastestOffset = endOffset;
    }

    public void flushLocation(
        uint beginLine,
        uint beginColumn,
        uint beginOffset,
        uint endLine,
        uint endColumn,
        uint endOffset,
        bool separate = true)
    {
        flushLocationBegin(beginLine, beginColumn, beginOffset, separate);
        flushLocationEnd(endLine, endColumn, endOffset);
    }

    public void flushLocation(
        uint line,
        uint column,
        uint offset,
        bool separate = true)
    {
        flushLocation(line, column, offset, line, column, offset, separate);
    }

    public void flushLocation(in SourceLocation location, bool separate = true)
    {
        flushLocation(
            location.line,
            location.column,
            location.offset,
            separate);
    }

    public void flushLocation(in SourceRange range, bool separate = true)
    {
        SourceLocation begin = range.start;
        SourceLocation end = range.end;

        flushLocation(
            begin.line,
            begin.column,
            begin.offset,
            end.line,
            end.column,
            end.offset,
            separate);
    }

    public void flushLocation(in Cursor cursor, bool separate = true)
    {
        flushLocation(cursor.extent, separate);
    }

    public bool flushHeaderComment()
    {
        if (commentIndex && commentIndex.isHeaderCommentPresent)
        {
            auto location = commentIndex.queryHeaderCommentExtent.end;
            headerEndOffset = location.offset + 2;
            flushLocation(location, false);
            return true;
        }
        else
        {
            return false;
        }
    }

    public string data(string suffix = "")
    {
        if (!suffix.empty)
            return buffer.data() ~ suffix;
        else
            return buffer.data();
    }

    public string header()
    {
        import std.algorithm.comparison;

        return buffer.data[0..min(headerEndOffset, $)];
    }

    public string content()
    {
        import std.algorithm.comparison;

        return buffer.data[min(headerEndOffset, $)..$];
    }

    struct Indent
    {
        private Output output;
        private string sentinel;
        private uint line = 0;
        private uint column = 0;
        private uint offset = 0;

        ~this()
        {
            bool flushed = output.flush(false);

            if (offset != 0)
                output.flushLocationEnd(line, column, offset);

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

    private bool flush(bool brace = true)
    {
        // Handle a case when there is only line in sub-scope.
        // When there is only single line, no braces should be put.

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
