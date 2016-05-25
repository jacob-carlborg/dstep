/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Mar 21, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

module dstep.translator.Context;

import mambo.core._;

import clang.c.Index;
import clang.Cursor;
import clang.TranslationUnit;

import dstep.translator.CommentIndex;
import dstep.translator.IncludeHandler;
import dstep.translator.MacroIndex;
import dstep.translator.Options;

class Context
{
    public MacroIndex macroIndex;
    public TranslationUnit translUnit;

    private string[Cursor] anonymousNames;
    private IncludeHandler includeHandler_;
    private CommentIndex commentIndex_ = null;

    public this(TranslationUnit translUnit, Options options)
    {
        this.translUnit = translUnit;
        macroIndex = new MacroIndex(translUnit);
        includeHandler_ = new IncludeHandler();

        if (options.enableComments)
            commentIndex_ = new CommentIndex(translUnit);
    }

    public string getAnonymousName (Cursor cursor)
    {
        if (auto name = cursor in anonymousNames)
            return *name;

        return "";
    }

    public string generateAnonymousName (Cursor cursor)
    {
        import std.format : format;

        auto name = getAnonymousName(cursor);

        if (name.isBlank)
        {
            name = format("_Anonymous_%d", anonymousNames.length);
            anonymousNames[cursor] = name;
        }

        return name;
    }

    @property public IncludeHandler includeHandler()
    {
        return includeHandler_;
    }

    @property public CommentIndex commentIndex()
    {
        return commentIndex_;
    }
}
