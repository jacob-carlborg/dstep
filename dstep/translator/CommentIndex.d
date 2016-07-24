/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: May 19, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.CommentIndex;

import std.range;

import clang.c.Index;
import clang.Token;
import clang.SourceLocation;
import clang.SourceRange;
import clang.TranslationUnit;

class CommentIndex
{
    public struct Comment
    {
        string content;
        SourceRange extent;
        uint line;
        uint column;
        uint offset;

        this(Token token)
        {
            auto location = token.location;
            content = normalize(token.spelling);
            extent = token.extent;
            line = location.line;
            column = location.column;
            offset = location.offset;
        }

        size_t indentAmount() const
        {
            import std.string;
            import std.format;
            import std.algorithm.comparison;
            import std.algorithm.searching;

            size_t amount = this.column - 1;
            auto lines = lineSplitter(content);

            if (!lines.empty)
            {
                lines.popFront();

                foreach (line; lines)
                {
                    amount = min(
                        amount,
                        cast(size_t) countUntil!(a => a != ' ')(line));
                }
            }

            return amount;
        }

        int opCmp(ref const Comment s) const
        {
            return offset < s.offset ? -1 : (offset == s.offset ? 0 : 1);
        }

        int opCmp(uint s) const
        {
            return offset < s ? -1 : (offset == s ? 0 : 1);
        }

        private static bool isNormalized(string content)
        {
            import std.ascii : isWhite;
            import std.range : iota;
            import std.algorithm : canFind;

            return !iota(0, content.length).canFind!(
                i => content[i] == '\n' && content[i - 1].isWhite);
        }

        private static string normalize(string content)
        {
            import std.algorithm : map, splitter;
            import std.string : stripRight;

            if (isNormalized(content))
                return content;
            else
                return content.splitter("\n").map!(stripRight).join("\n");
        }

        unittest
        {
            assert(normalize("") == "");
            assert(normalize("foo") == "foo");
            assert(normalize("foo \n") == "foo\n");
            assert(normalize("foo \n  ") == "foo\n");
            assert(normalize("foo \n  bar \n  ") == "foo\n  bar\n");
            assert(normalize("foo \n  bar \n\n  ") == "foo\n  bar\n\n");
        }
    }

    private TranslationUnit translUnit;
    private Comment[] comments;
    private SourceRange lastTokenRange;
    private SourceLocation includeGuardLocation;
    private bool hasIncludeGuard = false;

    this(TranslationUnit translUnit)
    {
        import std.algorithm.iteration : filter, map;

        this.translUnit = translUnit;
        lastTokenRange = translUnit.cursor.extent;

        auto tokens = translUnit.cursor.tokens;

        if (!tokens.empty)
            lastTokenRange = tokens.back.extent;

        comments = tokens
            .filter!(token =>
                token.kind == CXTokenKind.CXToken_Comment &&
                token.location.isFromMainFile)
            .map!(token => Comment(token)).array;
    }

    this (TranslationUnit translUnit, SourceLocation includeGuardLocation)
    {
        this (translUnit);

        this.includeGuardLocation = includeGuardLocation;
        this.hasIncludeGuard = true;
    }

    auto queryComments(uint begin, uint end)
    {
        auto sorted = assumeSorted(comments);
        auto lower = sorted.lowerBound(end);

        if (lower.empty || begin == 0)
            return lower;
        else
            return lower.upperBound(begin - 1);
    }

    SourceLocation queryLastLocation()
    {
        return lastTokenRange.end;
    }

    /**
      * Returns true if a header comment is present.
      *
      * If include guard is present the header comment consists of all of the
      * comments before the header guard. Otherwise, the header comment is a
      * comment placed at the very beginning of the file, specifically it cannot
      * have any white-spaces before it.
      */
    bool isHeaderCommentPresent()
    {
        if (hasIncludeGuard)
            return !comments.empty &&
                comments.front.extent.end.offset < includeGuardLocation.offset;
        else
            return !comments.empty && comments.front.offset == 0;
    }

    SourceRange queryHeaderCommentExtent()
    {
        if (hasIncludeGuard)
        {
            import std.algorithm.searching : find;

            auto offset = includeGuardLocation.offset;
            auto prv = comments.front;

            foreach (itr; comments)
            {
                if (itr.offset >= offset)
                    break;

                prv = itr;
            }

            return translUnit.extent(
                comments.front.offset,
                prv.extent.end.offset);
        }
        else
        {
            return translUnit.extent(
                comments.front.offset,
                comments.front.offset + cast(uint) comments.front.content.length);
        }
    }
}
