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
import dstep.translator.Translator;
import dstep.translator.TypedefIndex;

class Context
{
    public MacroIndex macroIndex;
    public TranslationUnit translUnit;

    private string[Cursor] anonymousNames;
    private bool[Cursor] alreadyDefined_;
    private IncludeHandler includeHandler_;
    private CommentIndex commentIndex_ = null;
    private TypedefIndex typedefIndex_ = null;
    private Translator translator_ = null;

    public this(TranslationUnit translUnit, Options options, Translator translator)
    {
        this.translUnit = translUnit;
        macroIndex = new MacroIndex(translUnit);
        includeHandler_ = new IncludeHandler();

        if (options.enableComments)
            commentIndex_ = new CommentIndex(translUnit);

        typedefIndex_ = new TypedefIndex(translUnit);
        translator_ = translator;
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

    public IncludeHandler includeHandler()
    {
        return includeHandler_;
    }

    public CommentIndex commentIndex()
    {
        return commentIndex_;
    }

    public TypedefIndex typedefIndex()
    {
        return typedefIndex_;
    }

    public bool alreadyDefined(in Cursor cursor)
    {
        return (cursor in alreadyDefined_) !is null;
    }

    public void markAsDefined(in Cursor cursor)
    {
        alreadyDefined_[cursor] = true;
    }

    public Cursor typedefParent(in Cursor cursor)
    {
        return typedefIndex_.typedefParent(cursor);
    }

    public string translateSpelling(in Cursor cursor)
    {
        auto typedefp = typedefParent(cursor.canonical);

        if (typedefp.isValid &&
            (cursor.spelling == typedefp.spelling || cursor.spelling == ""))
            return typedefp.spelling;
        else
            return cursor.spelling == ""
                ? generateAnonymousName(cursor)
                : cursor.spelling;
    }

    public Translator translator()
    {
        return translator_;
    }
}
