/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import core.exception;

import std.stdio;
import std.random;
import std.file;
import std.path;
import std.conv;
import std.algorithm;
import std.array;

import clang.c.Index;

import dstep.translator.Translator;
import dstep.translator.Output;

public import clang.Compiler;
public import clang.Cursor;
public import clang.Index;
public import clang.TranslationUnit;
public import clang.Token;

Index index;

static this() 
{
    index = Index(false, false);
}

TranslationUnit makeTranslationUnit(string c) 
{
    return TranslationUnit.parseString(index, c, [], null, CXTranslationUnit_Flags.CXTranslationUnit_DetailedPreprocessingRecord);
}

string translate(TranslationUnit translationUnit) 
{
    resetOutput();
    auto translator = new Translator(translationUnit);
    return translator.translateToString();
}

class TranslateAssertError : AssertError 
{
    this (string message, string file, ulong line) 
    {
        super(message, file, line);
    }
}

void assertTranslates(string c, string d, string file = __FILE__, size_t line = __LINE__) 
{
    import std.format : format;

    auto translated = translate(makeTranslationUnit(c));
    auto fmt = q"/
C code translated to:
%1$s
%2$s
%1$s
Expected D code:
%1$s
%3$s
%1$s/";

    string message = format(fmt, "----------------", translated, d);

    if (translated != d) 
        throw new TranslateAssertError(message, file, line);
}
