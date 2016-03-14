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

import dstep.translator.IncludeHandler;
import dstep.translator.Output;
import dstep.translator.Translator;

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

void assertEq(string expected, string actual, string file = __FILE__, size_t line = __LINE__)
{
    import std.format : format;

    if (expected != actual)
    {
        string showWhitespaces(string x)
        {
            return x.replace(" ", "·").replace("\n", "↵\n");
        }

        auto templ = "\nExpected:\n%s\nActual:\n%s\n";
        string message = templ.format(
            showWhitespaces(expected),
            showWhitespaces(actual));
        throw new AssertError(message, file, line);
    }
}

TranslationUnit makeTranslationUnit(string c)
{
    return TranslationUnit.parseString(index, c, [], null, CXTranslationUnit_Flags.CXTranslationUnit_DetailedPreprocessingRecord);
}

string translate(TranslationUnit translationUnit, Language language)
{
    anonymousNames = string[Cursor].init;
    resetIncludeHandler();
    resetOutput();
    Translator.Options options;
    options.language = language;
    auto translator = new Translator(translationUnit, options);
    return translator.translateToString();
}

class TranslateAssertError : AssertError
{
    this (string message, string file, ulong line)
    {
        super(message, file, line);
    }
}

void assertTranslates(
    string expected,
    TranslationUnit unit,
    bool strict,
    Language language,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.format : format;
    import std.algorithm : map;
    import std.string : strip;

    auto sep = "----------------";

    if (unit.numDiagnostics != 0)
    {
        auto diagnostics = unit.diagnosticSet.map!(a => a.toString());
        string fmt = "\nCannot compile source code. Errors:\n%s\n %s";
        string message = fmt.format(sep, diagnostics.join("\n"));
        throw new TranslateAssertError(message, file, line);
    }

    auto translated = translate(unit, language);
    auto fmt = q"/
C code translated to:
%1$s
%2$s
%1$s
Expected D code:
%1$s
%3$s
%1$s
AST dump:
%4$s/";

    bool failed = translated != expected;

    if (failed && !strict)
        failed = translated.strip() != expected.strip();

    if (failed)
    {
        size_t maxSubmessageLength = 10_000;
        string astDump = unit.dumpAST(true);

        if (maxSubmessageLength < translated.length)
            translated = translated[0..maxSubmessageLength] ~ "...";

        if (maxSubmessageLength < astDump.length)
            astDump = astDump[0..maxSubmessageLength] ~ "...";

        string message = format(fmt, sep, translated, expected, astDump);
        throw new TranslateAssertError(message, file, line);
    }
}

void assertTranslates(string c, string d, bool strict = false, string file = __FILE__, size_t line = __LINE__)
{
    auto unit = makeTranslationUnit(c);
    assertTranslates(d, unit, strict, Language.c, file, line);
}

void assertTranslatesFile(
    string expectedPath,
    string objCPath,
    bool strict,
    Language language,
    string[] arguments,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string readFile(string path)
    {
        import std.stdio : File;
        auto file = File(path, "r");
        char[] buffer = new char[file.size];
        return file.rawRead(buffer).idup;
    }

    auto expected = readFile(expectedPath);
    auto unit = TranslationUnit.parse(index, objCPath, arguments);
    assertTranslates(expected, unit, strict, language, file, line);
}

string findGNUStepIncludePath()
{
    import std.file : isDir, exists;
    import std.format : format;

    string path = "/usr/include/GNUstep";

    if (exists(path) && isDir(path))
        return "-I%s".format(path);
    else
        return null;
}

string[] findCcIncludePaths()
{
    string[] extract(string output)
    {
        import std.algorithm.searching;
        import std.algorithm.iteration;
        import std.string;

        string start = "#include <...> search starts here:";
        string stop = "End of search list.";
        auto paths = output.findSplitAfter(start)[1].findSplitBefore(stop)[0].strip();
        return paths.empty ? null : map!(a => "-I%s".format(a))(paths.splitLines()).array;
    }

    import std.process : executeShell;
    auto result = executeShell("cc -E -v - < /dev/null");

    if (result.status == 0)
        return extract(result.output);
    else
        return null;
}

void assertTranslatesCFile(
    string expectedPath,
    string cPath,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] arguments = ["-Iresources"];

    assertTranslatesFile(
        expectedPath,
        cPath,
        strict,
        Language.c,
        arguments,
        file,
        line);
}

void assertTranslatesObjCFile(
    string expectedPath,
    string objCPath,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] arguments = ["-ObjC", "-Iresources"];

    version (linux)
    {
        import std.stdio : stderr;
        import std.format : format;

        auto gnuStepPath = findGNUStepIncludePath();

        if (gnuStepPath == null)
        {
            auto message = "Unable to check the assertion. GNUstep couldn't be found.";
            stderr.writeln("Warning@%s(%d): %s".format(file, line, message));
            return;
        }

        auto ccIncludePaths = findCcIncludePaths();

        if (ccIncludePaths == null)
        {
            auto message = "Unable to check the assertion. cc include paths couldn't be found.";
            stderr.writeln("Warning@%s(%d): %s".format(file, line, message));
            return;
        }

        arguments ~= ccIncludePaths;
        arguments ~= gnuStepPath;
    }

    assertTranslatesFile(
        expectedPath,
        objCPath,
        strict,
        Language.objC,
        arguments,
        file,
        line);
}
