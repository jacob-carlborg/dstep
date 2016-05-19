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

        int opCmp(ref const Comment s) const
        {
            return offset < s.offset ? -1 : (offset == s.offset ? 0 : 1);
        }

        int opCmp(uint s) const
        {
            return offset < s ? -1 : (offset == s ? 0 : 1);
        }
    }

    private TranslationUnit translUnit;
    private Comment[] comments;
    private SourceRange lastTokenRange;

    this(TranslationUnit translUnit)
    {
        this.translUnit = translUnit;

        lastTokenRange = translUnit.cursor.extent;

        foreach (token; translUnit.cursor.tokens)
        {
            lastTokenRange = token.extent;

            if (token.kind == CXTokenKind.CXToken_Comment)
            {
                auto location = token.location;

                if (location.isFromMainFile)
                {
                    Comment comment = {
                        token.spelling,
                        token.extent,
                        location.line,
                        location.column,
                        location.offset };

                    comments ~= comment;
                }
            }
        }
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

    bool isHeaderCommentPresent()
    {
        return !comments.empty && comments.front.offset == 0;
    }

    SourceRange queryHeaderCommentExtent()
    {
        return translUnit.extent(
            comments.front.offset,
            comments.front.offset + cast (uint) comments.front.content.length);
    }
}
