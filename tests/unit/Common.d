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
import std.typecons;
import std.traits : ReturnType;
import std.process : execute;

import clang.c.Index;
import clang.Diagnostic;

import dstep.driver.Application;
import dstep.translator.CommentIndex;
import dstep.translator.Context;
import dstep.translator.IncludeHandler;
import dstep.translator.MacroDefinition;
import dstep.translator.MacroParser;
import dstep.translator.Options;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.Configuration;

public import clang.Compiler;
public import clang.Cursor;
public import clang.Index;
public import clang.TranslationUnit;
public import clang.Token;

Index index;

version (linux)
{
    version = OptionalGNUStep;
}

version (Windows)
{
    version = OptionalGNUStep;
}

static this()
{
    index = Index(false, false);
}

bool compareString(string a, string b, bool strict)
{
    import std.string : strip;

    if (strict)
        return a == b;
    else
        return a.strip() == b.strip();
}

void assertEq(
    string expected,
    string actual,
    bool strict = true,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.format : format;

    if (!compareString(expected, actual, strict))
    {
        string showWhitespaces(string x)
        {
            return x.replace(" ", "·").replace("\n", "↵\n");
        }

        auto templ = "\nExpected:\n%s\nActual:\n%s\n";
        string message = format(
            templ,
            showWhitespaces(expected),
            showWhitespaces(actual));
        throw new AssertError(message, file, line);
    }
}

TranslationUnit makeTranslationUnit(string source)
{
    auto arguments = ["-Iresources", "-Wno-missing-declarations"];

    arguments ~= findExtraIncludePaths();

    return TranslationUnit.parseString(index, source, arguments);
}

CommentIndex makeCommentIndex(string c)
{
    TranslationUnit translUnit = makeTranslationUnit(c);
    return new CommentIndex(translUnit);
}

MacroDefinition parseMacroDefinition(string source)
{
    import dstep.translator.MacroParser : parseMacroDefinition;

    Token[] tokenize(string source)
    {
        auto translUnit = makeTranslationUnit(source);
        return translUnit.tokenize(translUnit.extent(0, cast(uint) source.length));
    }

    Token[] tokens = tokenize(source);

    Cursor[string] dummy;

    return parseMacroDefinition(tokens, dummy);
}

void assertCollectsTypeNames(string[] expected, string source, string file = __FILE__, size_t line = __LINE__)
{
    import std.format : format;

    auto translUnit = makeTranslationUnit(source);
    Cursor[string] types, consts;
    collectGlobalNames(translUnit, types, consts);

    foreach (name; expected)
    {
        if ((name in types) is null)
            throw new AssertError(format("`%s` was not found.", name), file, line);
    }
}

string translate(TranslationUnit translationUnit, Options options)
{
    auto translator = new Translator(translationUnit, options);
    return translator.translateToString();
}

class TranslateAssertError : AssertError
{
    this (string message, string file, size_t line)
    {
        super(message, file, line);
    }
}

void assertTranslates(
    string expected,
    TranslationUnit translUnit,
    Options options,
    bool strict,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.format : format;
    import std.algorithm : map;

    import tests.support.Util;

    auto sep = "----------------";

    if (translUnit.numDiagnostics != 0)
    {
        auto diagnosticSet = translUnit.diagnosticSet;

        if (diagnosticSet.hasError)
        {
            auto diagnostics = diagnosticSet.map!(a => a.toString());
            string fmt = "\nCannot compile source code. Errors:\n%s\n %s";
            string message = fmt.format(sep, diagnostics.join("\n"));
            throw new TranslateAssertError(message, file, line);
        }
    }

    options.printDiagnostics = false;

    auto translated = translate(translUnit, options);
    auto mismatch = mismatchRegionTranslated(translated, expected, 8, strict);

    if (mismatch)
    {
        size_t maxSubmessageLength = 10_000;
        string astDump = translUnit.dumpAST(true);

        if (maxSubmessageLength < astDump.length)
            astDump = astDump[0 .. maxSubmessageLength] ~ "...";

        string message = format("\n%s\nAST dump:\n%s", mismatch, astDump);

        throw new AssertError(message, file, line);
    }
}

void assertTranslates(
    string c,
    string d,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    auto translUnit = makeTranslationUnit(c);
    Options options;

    if (options.inputFile.empty)
        options.inputFile = translUnit.spelling;

    options.language = Language.c;
    assertTranslates(d, translUnit, options, strict, file, line);
}

void assertTranslates(
    string c,
    string d,
    Options options,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    auto translUnit = makeTranslationUnit(c);

    if (options.inputFile.empty)
        options.inputFile = translUnit.spelling;

    assertTranslates(d, translUnit, options, strict, file, line);
}

string[] findExtraIncludePaths()
{
    import clang.Util : clangVersion;

    version (Windows)
    {
        auto ver = clangVersion();

        if (ver.major == 3 && ver.minor == 7)
            return findMinGWIncludePaths();
    }

    return [];
}

string[] findMinGWIncludePaths()
{
    string sample = "c:\\MinGW\\include\\stdio.h";
    string include = "-Ic:\\MinGW\\include";

    if (exists(sample) && isFile(sample))
        return [include];
    else
        return null;
}
