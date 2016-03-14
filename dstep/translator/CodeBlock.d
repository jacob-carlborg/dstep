/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Mar 11, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

module dstep.translator.CodeBlock;

import std.array;
import std.string;

enum EndlHint
{
    /// Does nothing, useful for cases when the translator doesn't produce any ouput.
    empty,

    /// Special node for grouping, puts an extra new line after grouped items, should not have spelling.
    group,

    /// Single line item, should not have children.
    singleLine,

    /// Multiline item, the children are indented.
    multiLine,

    /// Puts braces if children takes more than single line, useful e.g for loops.
    subscopeWeak,

    /// Always puts braces, useful e.g. for classes.
    subscopeStrong,
}

struct CodeBlock
{
    string spelling;
    EndlHint endlHint;
    CodeBlock[] children;

    this(string spelling, EndlHint endlHint, CodeBlock[] children = [])
    {
        this.spelling = spelling;
        this.endlHint = endlHint;
        this.children = children;
    }

    this(EndlHint endlHint, CodeBlock[] children = [])
    {
        this.spelling = "";
        this.endlHint = endlHint;
        this.children = children;
    }

    this(string spelling)
    {
        this.spelling = spelling;
        this.endlHint = EndlHint.singleLine;
        this.children = [];
    }

    this(CodeBlock[] children)
    {
        this.spelling = null;
        this.endlHint = EndlHint.group;
        this.children = children;
    }
}

size_t countLines(in CodeBlock block)
{
    // this desires to be implemented in more efficient way
    return compose(block).count("\n");
}

size_t countLines(in CodeBlock[] blocks)
{
    // this desires to be implemented in more efficient way
    auto output = appender!string();
    compose(output, blocks, 0);
    return output.data.count("\n");
}

void compose(ref Appender!string output, in CodeBlock[] blocks, size_t indent)
{
    bool isSubscope(EndlHint hint)
    {
        return hint == EndlHint.subscopeWeak || hint == EndlHint.subscopeStrong;
    }

    if (!blocks.empty)
    {
        compose(output, blocks[0], indent);

        foreach (i; 1 .. blocks.length)
        {
            if (isSubscope(blocks[i - 1].endlHint)
                || (isSubscope(blocks[i].endlHint) && blocks[i - 1].endlHint != EndlHint.empty))
                output.put("\n");

            compose(output, blocks[i], indent);
        }
    }
}

void compose(ref Appender!string output, in CodeBlock block, size_t indent)
{
    immutable string tab = "    ";

    output.put(tab.replicate(indent));
    output.put(block.spelling);

    final switch (block.endlHint)
    {
        case EndlHint.empty:
            break;

        case EndlHint.group:
            compose(output, block.children, indent);

            if (!output.data.endsWith("\n\n"))
                output.put("\n");

            break;

        case EndlHint.singleLine:
            output.put("\n");
            break;

        case EndlHint.multiLine:
            output.put("\n");
            compose(output, block.children, indent + 1);
            break;

        case EndlHint.subscopeWeak:
            if (countLines(block.children) == 1)
            {
                output.put("\n");
                compose(output, block.children, indent + 1);
                break;
            }

        case EndlHint.subscopeStrong:
            output.put("\n");
            output.put(tab.replicate(indent));
            output.put("{\n");
            compose(output, block.children, indent + 1);
            output.put(tab.replicate(indent));
            output.put("}\n");
            break;
    }
}

string compose(in CodeBlock block)
{
    auto output = appender!string();

    compose(output, block, 0);

    return output.data;
}
