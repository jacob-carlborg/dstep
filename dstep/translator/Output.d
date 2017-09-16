/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Output;

import std.array;
import std.typecons;
import std.variant;

import clang.Cursor;
import clang.SourceLocation;
import clang.SourceRange;
import clang.Util;

import dstep.translator.CommentIndex;
import dstep.translator.Context;
import dstep.translator.IncludeHandler;
import dstep.translator.Type;

struct SourceLeaf
{
    string spelling;
    SourceRange extent;
}

SourceLeaf makeSourceLeaf(
    string spelling,
    SourceRange extent = SourceRange.empty)
{
    SourceLeaf result;
    result.spelling = spelling;
    result.extent = extent;
    return result;
}

struct SourceNode
{
    alias Child = Algebraic!(SourceNode*, SourceLeaf);
    string prefix;
    string suffix;
    string separator;
    Child[] children;
    SourceRange extent;
}

SourceNode makeSourceNode(
    string prefix,
    string[] children,
    string separator,
    string suffix,
    SourceRange extent = SourceRange.empty)
{
    import std.algorithm;
    SourceNode node;
    node.prefix = prefix;
    node.suffix = suffix;
    node.separator = separator;
    node.children = children.map!(x => SourceNode.Child(SourceLeaf(x))).array;
    node.extent = extent;
    return node;
}

SourceNode makeSourceNode(SourceLeaf leaf)
{
    SourceNode node;
    node.prefix = leaf.spelling;
    node.extent = leaf.extent;
    return node;
}

SourceNode makeSourceNode(
    string spelling,
    SourceRange extent = SourceRange.empty)
{
    SourceNode node;
    node.prefix = spelling;
    node.extent = extent;
    return node;
}

SourceNode suffixWith(SourceNode node, string suffix)
{
    SourceNode result = node;
    result.suffix = result.suffix ~ suffix;
    return result;
}

SourceNode prefixWith(SourceNode node, string prefix)
{
    SourceNode result = node;
    result.prefix = prefix ~ result.prefix;
    return result;
}

SourceNode wrapWith(SourceNode node, string prefix, string suffix)
{
    SourceNode result = node;
    result.prefix = prefix ~ result.prefix;
    result.suffix = result.suffix ~ suffix;
    return result;
}

SourceNode flatten(in SourceNode node)
{
    void flatten(ref Appender!(char[]) output, in SourceNode node)
    {

        output.put(node.prefix);

        foreach (index, child; node.children)
        {
            if (child.type() == typeid(SourceLeaf))
                output ~= child.get!(SourceLeaf).spelling;
            else
                flatten(output, *child.get!(SourceNode*));

            if (index + 1 != node.children.length)
                output.put(node.separator ~ " ");
        }

        output.put(node.suffix);
    }

    Appender!(char[]) output;
    flatten(output, node);
    return output.data.idup.makeSourceNode();
}

string makeString(in SourceNode node)
{
    import std.range;
    auto flattened = node.flatten();
    assert(flattened.children.empty);
    assert(flattened.suffix.empty);
    return flattened.prefix;
}

void adaptiveSourceNode(Output output, in SourceNode node)
{
    auto format = node.prefix ~ "%@" ~ node.separator ~ "%@" ~ node.suffix;

    output.adaptiveLine(node.extent, format) in
    {
        foreach (child; node.children)
        {
            if (child.type() == typeid(SourceLeaf))
            {
                auto leaf = child.get!(SourceLeaf);
                output.adaptiveLine(leaf.extent, leaf.spelling);
            }
            else
                adaptiveSourceNode(output, *child.get!(SourceNode*));
        }
    };
}

unittest
{
    SourceNode node = makeSourceNode(
        "prefix(", [], ",", ");");

    assert(makeString(node) == "prefix();");
}

unittest
{
    SourceNode node = makeSourceNode(
        "prefix(", ["a", "b"], ",", ");");

    assert(makeString(node) == "prefix(a, b);");
}

unittest
{
    SourceNode node = makeSourceNode("prefix(a, b);");

    assert(makeString(node) == "prefix(a, b);");
}

class Output
{
    private enum Entity
    {
        bottom,
        separator,
        comment,
        singleLine,
        adaptiveLine,
        multiLine,
        subscopeWeak,
        subscopeStrong,
    }

    private enum ChunkType
    {
        opening,
        closing,
        item,
    }

    private struct Chunk
    {
        ChunkType type;
        string content;
        string separator;
    }

    const size_t marginSize = 80;
    const size_t indentSize = 4;
    private Appender!(char[]) buffer;
    private Appender!(char[]) weak;
    private Entity[] stack;
    private Entity first = Entity.bottom;
    private Appender!(Chunk[]) chunks;
    private CommentIndex commentIndex = null;

    private uint lastestOffset = 0;
    private uint lastestLine = 0;
    private uint headerEndOffset = 0;

    this(Output parent)
    {
        stack ~= Entity.bottom;

        // formattedWrite will not write anything
        // to the output range if put was not invoked before.
        buffer.put("");
        weak.put("");
        commentIndex = parent.commentIndex;
        lastestOffset = parent.lastestOffset;
        lastestLine = parent.lastestLine;
    }

    this(
        CommentIndex commentIndex = null,
        size_t marginSize = 80,
        size_t indentSize = 4)
    {
        this.marginSize = marginSize;
        this.indentSize = indentSize;

        stack ~= Entity.bottom;

        // formattedWrite will not write anything
        // to the output range if put was not invoked before.
        buffer.put("");
        weak.put("");

        this.commentIndex = commentIndex;
    }

    public void reset()
    {
        buffer.clear();
        weak.clear();

        // formattedWrite will not write anything
        // to the output range if put was not invoked before.
        buffer.put("");
        weak.put("");

        stack = [ Entity.bottom ];

        first = Entity.bottom;
        chunks.clear();

        lastestOffset = 0;
        lastestLine = 0;
        headerEndOffset = 0;
    }

    public bool empty()
    {
        return stack.length == 1 && stack.back == Entity.bottom;
    }

    public void separator()
    {
        if (stack.back == Entity.singleLine ||
            stack.back == Entity.adaptiveLine ||
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
                output.first != Entity.singleLine) &&
                (stack.back != Entity.singleLine ||
                output.first != Entity.adaptiveLine) &&
                (stack.back != Entity.adaptiveLine ||
                output.first != Entity.adaptiveLine))
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

        if (stack.back != Entity.singleLine &&
            stack.back != Entity.adaptiveLine)
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
                stack.back != Entity.adaptiveLine &&
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

    private Tuple!(string, string, string) adaptiveLineParts(Char, Args...)(
        in Char[] fmt,
        Args args)
    {
        import std.algorithm.searching;
        import std.format : format;

        size_t findPlaceholder(in Char[] fmt)
        {
            foreach (i; 0 .. fmt.length)
            {
                if (fmt[i] == '@' && i != 0)
                {
                    size_t j = i;

                    while (i != 0 && fmt[i - 1] == '%')
                        --i;

                    if ((i - j) % 2 == 1)
                        return i;
                }
            }

            return fmt.length;
        }

        size_t begin = findPlaceholder(fmt);

        if (begin != fmt.length)
        {
            string separator, opening, closing;
            size_t end = findPlaceholder(fmt[begin + 2 .. $]) + begin + 2;

            if (end != fmt.length)
                separator = fmt[begin + 2 .. end].idup;
            else
                end = begin;

            size_t minUnique = count(fmt, '@') + 1;
            auto sentinel = replicate("@", minUnique);

            auto split = format(
                fmt[0 .. begin] ~
                sentinel ~
                fmt[end + 2 .. $],
                args).findSplit(sentinel);

            return tuple(split[0], separator, split[2]);
        }
        else
        {
            return tuple(format(fmt, args), "", "");
        }
    }

    private string adaptiveLineImpl(Char, Args...)(in Char[] fmt, Args args)
    {
        if (stack.length != 1 &&
            stack[$ - 2] != Entity.adaptiveLine ||
            stack.length == 1)
        {
            if (stack.back != Entity.singleLine &&
                stack.back != Entity.adaptiveLine &&
                stack.back != Entity.bottom &&
                stack.back != Entity.comment)
                buffer.put("\n");

            if (stack.back != Entity.bottom)
                buffer.put("\n");
        }

        stack.back = Entity.adaptiveLine;
        stack ~= Entity.bottom;

        if (first == Entity.bottom)
            first = Entity.adaptiveLine;

        auto parts = adaptiveLineParts(fmt, args);

        chunks.put(Chunk(ChunkType.opening, parts[0], parts[1]));
        return parts[2];
    }

    public Indent adaptiveLine(Char, Args...)(in Char[] fmt, Args args)
    {
        return Indent(this, adaptiveLineImpl(fmt, args));
    }

    /**
     * adaptiveLine adds a line to the output that is automatically broken to
     * multiple lines, if it's too long (80 characters).
     *
     * It takes a special format specifier that is replaced with other nested
     * adaptive lines. The specifier has form `%@<separator>%@`, where
     * <separator> is a string that separates the items/lines (the spaces and
     * end-lines are added automatically).
     */
    public Indent adaptiveLine(Char, Args...)(
        in SourceRange extent,
        in Char[] fmt,
        Args args)
    {
        SourceLocation start = extent.start;
        SourceLocation end = extent.end;

        flushLocationBegin(start.line, start.column, start.offset);

        return Indent(
            this,
            adaptiveLineImpl(fmt, args),
            end.line,
            end.column,
            end.offset);
    }

    ///
    unittest
    {
        // Simple item.
        auto example1 = new Output();

        example1.adaptiveLine("foo");

        assert(example1.data() == "foo");

        // Inline function.
        auto example2 = new Output();

        example2.adaptiveLine("void foo(%@,%@);") in {
            example2.adaptiveLine("int bar");
            example2.adaptiveLine("int baz");
        };

        assert(example2.data() == "void foo(int bar, int baz);");

        // Broken function.
        auto example3 = new Output();

        example3.adaptiveLine("void foo(%@,%@);") in {
            example3.adaptiveLine("int bar0");
            example3.adaptiveLine("int bar1");
            example3.adaptiveLine("int bar2");
            example3.adaptiveLine("int bar3");
            example3.adaptiveLine("int bar4");
            example3.adaptiveLine("int bar5");
            example3.adaptiveLine("int bar6");
            example3.adaptiveLine("int bar7");
            example3.adaptiveLine("int bar8");
        };

        assert(example3.data() ==
q"D
void foo(
    int bar0,
    int bar1,
    int bar2,
    int bar3,
    int bar4,
    int bar5,
    int bar6,
    int bar7,
    int bar8);
D"[0 .. $ - 1]);

        // The adaptive lines can be nested multiple times. Breaking algorithm
        // will try to break only the most outer levels. The %@<sep>%@ can be
        // mixed with standard format specifiers.
        auto example4 = new Output();

        example4.adaptiveLine("foo%d%s(%@,%@);", 123, "bar") in {
            example4.adaptiveLine("bar0");
            example4.adaptiveLine("bar1");
            example4.adaptiveLine("bar2");
            example4.adaptiveLine("baz(%@ +%@)") in {
                example4.adaptiveLine("0");
                example4.adaptiveLine("1");
                example4.adaptiveLine("2");
                example4.adaptiveLine("3");
                example4.adaptiveLine("4");
            };
            example4.adaptiveLine("bar4");
            example4.adaptiveLine("bar5");
            example4.adaptiveLine("bar6");
            example4.adaptiveLine("bar7");
            example4.adaptiveLine("bar8");
        };

        assert(example4.data() ==
q"D
foo123bar(
    bar0,
    bar1,
    bar2,
    baz(0 + 1 + 2 + 3 + 4),
    bar4,
    bar5,
    bar6,
    bar7,
    bar8);
D"[0 .. $ - 1]);

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

    private void writeComment(in CommentIndex.Comment comment)
    {
        import std.string;
        import std.format;

        auto lines = lineSplitter!(KeepTerminator.yes)(comment.content);

        if (!lines.empty)
        {
            size_t indentAmount = comment.indentAmount;

            if (lastestLine != comment.line)
                indent();

            buffer.put(lines.front);
            lines.popFront;

            foreach (line; lines)
            {
                indent();
                buffer.put(line[indentAmount .. $]);
            }
        }
    }

    private void comment(in CommentIndex.Comment comment)
    {
        if (lastestLine == comment.line)
        {
            buffer.put(" ");
        }
        else if (stack.back != Entity.bottom)
        {
            if (lastestLine + 1 < comment.line ||
                (stack.back != Entity.singleLine &&
                stack.back != Entity.adaptiveLine &&
                stack.back != Entity.comment))
                buffer.put('\n');

            buffer.put('\n');
        }

        writeComment(comment);

        stack.back = Entity.comment;

        if (first == Entity.bottom)
            first = Entity.comment;

        lastestLine = comment.extent.end.line;
        lastestOffset = comment.extent.end.offset;
    }

    private void flushComments(uint offset)
    {
        if (lastestOffset < offset && commentIndex)
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

            if (stack.back == Entity.separator)
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

        import std.algorithm.comparison;

        lastestLine = max(endLine, lastestLine);
        lastestOffset = max(endOffset, lastestOffset);
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
            return (buffer.data() ~ suffix).idup;
        else
            return buffer.data().idup;
    }

    public string header()
    {
        import std.algorithm.comparison;

        return buffer.data[0 .. min(headerEndOffset, $)].idup;
    }

    public string content()
    {
        import std.algorithm.comparison;

        return buffer.data[min(headerEndOffset, $) .. $].idup;
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
            if (output.stack.length > 1 &&
                output.stack[$ - 2] == Entity.adaptiveLine)
            {
                if (offset != 0)
                    output.flushLocationEnd(line, column, offset);

                output.stack.popBack();

                auto data = output.chunks.data;

                if (data.back.type == ChunkType.opening)
                {
                    data.back.type = ChunkType.item;
                    data.back.content ~= sentinel;
                }
                else
                {
                    output.chunks.put(Chunk(ChunkType.closing, sentinel));
                }

                if (output.stack.length == 1 ||
                    output.stack[$ - 2] != Entity.adaptiveLine)
                    output.resolveAdaptive();
            }
            else
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

    private Tuple!(size_t, size_t) resolveAdaptiveWidth(size_t itr)
    {
        auto data = chunks.data;
        string[] separators = [ data[itr].separator ];
        size_t jtr = itr + 1;
        size_t width = data[itr].content.length;

        size_t separator(size_t jtr, size_t width)
        {
            if (jtr + 1 < data.length &&
                separators.length != 0 &&
                data[jtr + 1].type != ChunkType.closing &&
                width != 0)
                return separators.back.length + 1;
            else
                return 0;
        }

        while (separators.length != 0)
        {
            final switch (data[jtr].type)
            {
                case ChunkType.opening:
                    width += data[jtr].content.length;
                    separators ~= data[jtr].separator;
                    break;

                case ChunkType.closing:
                    separators = separators[0 .. $ - 1];
                    width +=
                        data[jtr].content.length +
                        separator(jtr, width);
                    break;

                case ChunkType.item:
                    width +=
                        data[jtr].content.length +
                        separator(jtr, width);
                    break;
            }

            ++jtr;
        }

        return tuple(width, jtr);
    }

    private void resolveAdaptiveAppend(size_t itr)
    {
        auto data = chunks.data;
        string[] separators = [ data[itr].separator ];
        size_t jtr = itr + 1;

        buffer.put(data[itr].content);

        while (separators.length != 0)
        {
            final switch (data[jtr].type)
            {
                case ChunkType.opening:
                    buffer.put(data[jtr].content);
                    separators ~= data[jtr].separator;
                    break;

                case ChunkType.closing:
                    separators = separators[0 .. $ - 1];
                    buffer.put(data[jtr].content);

                    if (jtr + 1 < data.length && separators.length != 0 &&
                        data[jtr + 1].type != ChunkType.closing)
                    {
                        buffer.put(separators.back);
                        buffer.put(" ");
                    }

                    break;

                case ChunkType.item:
                    buffer.put(data[jtr].content);

                    if (jtr + 1 < data.length && separators.length != 0 &&
                        data[jtr + 1].type != ChunkType.closing)
                    {
                        buffer.put(separators.back);
                        buffer.put(" ");
                    }

                    break;
            }

            ++jtr;
        }
    }

    private void resolveAdaptive()
    {
        string[] separators;
        size_t amount = (stack.length - 1) * indentSize;
        size_t itr = 0;

        auto data = chunks.data;
        auto feed = "";

        while (itr < data.length)
        {
            if (data[itr].type == ChunkType.opening)
            {
                auto tuple = resolveAdaptiveWidth(itr);

                size_t width =
                    amount + separators.length * indentSize + tuple[0];

                if (width < marginSize)
                {
                    buffer.put(feed);
                    indent(separators.length);
                    resolveAdaptiveAppend(itr);

                    if (tuple[1] < data.length &&
                        data[tuple[1]].type != ChunkType.closing)
                        buffer.put(separators.back);

                    itr = tuple[1];
                }
                else
                {
                    buffer.put(feed);
                    indent(separators.length);
                    buffer.put(data[itr].content);
                    separators ~= data[itr].separator;

                    ++itr;
                }

                feed = "\n";
            }
            else if (data[itr].type == ChunkType.closing)
            {
                separators = separators[0..$-1];
                buffer.put(data[itr].content);

                if (itr + 1 < data.length &&
                    data[itr + 1].type != ChunkType.closing &&
                    separators.length != 0)
                    buffer.put(separators.back);

                ++itr;

                feed = "\n";
            }
            else
            {
                buffer.put(feed);
                indent(separators.length);

                if (!data[itr].content.empty)
                {
                    buffer.put(data[itr].content);

                    if (itr + 1 < data.length &&
                        data[itr + 1].type != ChunkType.closing)
                        buffer.put(separators.back);

                    feed = "\n";
                }

                ++itr;
            }
        }

        chunks = appender!(Chunk[])();
    }

    private void indent()
    {
        foreach (x; 0 .. stack.length - 1)
            buffer.put("    ");
    }

    private void indent(int shift)
    {
        foreach (x; 0 .. stack.length - 1 + shift)
            buffer.put("    ");
    }

    private void indent(size_t shift)
    {
        foreach (x; 0 .. stack.length - 1 + shift)
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

        if (name.length)
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

class ClassData : StructData
{
    Output[] members;

    string name;
    string superclass;
    string[] interfaces;

    Set!string propertyList;

    private Set!string mangledMethods;

    this (Context context)
    {
        super(context);
    }

    string getMethodName (FunctionCursor func, string name = "", bool translateIdentifier = true)
    {
        import std.range : empty;

        auto mangledName = mangle(func, name);
        auto selector = func.spelling;

        if (!(mangledName in mangledMethods))
        {
            mangledMethods.add(mangledName);
            name = name.empty ? selector : name;
            return translateSelector(name, false, translateIdentifier);
        }

        return translateSelector(name, true, translateIdentifier);
    }

    private string mangle (FunctionCursor func, string name)
    {
        import std.range : empty;
        auto selector = func.spelling;
        name = name.empty ? translateSelector(selector) : name;
        auto mangledName = name;

        foreach (param ; func.parameters)
            mangledName ~= translateType(context, param).prefixWith("_").makeString();

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

        if (superclass.length)
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
        import std.range : empty;

        if (interfaces.length)
        {
            if (superclass.empty)
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
