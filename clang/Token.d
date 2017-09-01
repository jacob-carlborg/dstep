/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Token;

import std.conv : to;
import std.typecons;
public import std.range.primitives : empty, front, back;

import clang.c.Index;
import clang.SourceLocation;
import clang.SourceRange;
import clang.Type;
import clang.Util;
import clang.Visitor;
import clang.Cursor;

enum TokenKind
{
    punctuation = CXTokenKind.punctuation,
    keyword = CXTokenKind.keyword,
    identifier = CXTokenKind.identifier,
    literal = CXTokenKind.literal,
    comment = CXTokenKind.comment,
}

TokenKind toD(CXTokenKind kind)
{
    return cast(TokenKind) kind;
}

struct Token
{
    TokenKind kind;
    string spelling;
    SourceRange extent;

    @property SourceLocation location()
    {
        return extent.start;
    }

    @property string toString() const
    {
        import std.format: format;
        return format("Token(kind = %s, spelling = %s)", kind, spelling);
    }
}

SourceRange extent(Token[] tokens)
{
    if (!tokens.empty)
        return SourceRange(
            tokens.front.extent.start,
            tokens.back.extent.end);
    else
        return SourceRange.empty;
}
