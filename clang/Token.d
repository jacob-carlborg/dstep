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
    punctuation = CXTokenKind.CXToken_Punctuation,
    keyword = CXTokenKind.CXToken_Keyword,
    identifier = CXTokenKind.CXToken_Identifier,
    literal = CXTokenKind.CXToken_Literal,
    comment = CXTokenKind.CXToken_Comment,
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
