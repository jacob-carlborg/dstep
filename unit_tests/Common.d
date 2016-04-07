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

void assertEq(
    string expected,
    string actual,
    string file = __FILE__,
    size_t line = __LINE__)
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

void assertFileExists(
    string expected,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.file : exists, isFile;
    import std.format : format;

    if (!exists(expected) || !isFile(expected))
    {
        auto message = format("File %s doesn't exist.", expected);
        throw new AssertError(message, file, line);
    }
}

TranslationUnit makeTranslationUnit(string c)
{
    return TranslationUnit.parseString(
        index,
        c,
        [],
        null,
        CXTranslationUnit_Flags.CXTranslationUnit_DetailedPreprocessingRecord);
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

bool compareString(string a, string b, bool strict)
{
    import std.string : strip;

    if (strict)
        return a == b;
    else
        return a.strip() == b.strip();
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

    auto sep = "----------------";

    if (unit.numDiagnostics != 0)
    {
        auto diagnostics = unit.diagnosticSet.map!(a => a.toString());
        string fmt = "\nCannot compile source code. Errors:\n%s\n %s";
        string message = fmt.format(sep, diagnostics.join("\n"));
        throw new TranslateAssertError(message, file, line);
    }

    auto translated = translate(unit, language);

    if (!compareString(expected, translated, strict))
    {
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

void assertTranslates(string c,
    string d,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    auto unit = makeTranslationUnit(c);
    assertTranslates(d, unit, strict, Language.c, file, line);
}

void assertTranslatesFile(
    string expectedPath,
    string actualPath,
    bool strict,
    Language language,
    string[] arguments,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.file : readText;

    auto expected = readText(expectedPath);
    auto unit = TranslationUnit.parse(index, actualPath, arguments);
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

        auto paths = output.findSplitAfter(start)[1]
            .findSplitBefore(stop)[0].strip();
        auto args = map!(a => format("-I%s", a.strip()))(paths.splitLines());
        return paths.empty ? null : args.array;
    }

    import std.process : executeShell;
    auto result = executeShell("cc -E -v - < /dev/null");

    if (result.status == 0)
        return extract(result.output);
    else
        return null;
}

string[] findExtraGNUStepPaths(string file, size_t line)
{
    import std.stdio : stderr;
    import std.format : format;

    auto gnuStepPath = findGNUStepIncludePath();

    if (gnuStepPath == null)
    {
        auto message = "Unable to check the assertion. GNUstep couldn't be found.";
        stderr.writeln(format("Warning@%s(%d): %s", file, line, message));
        return [];
    }

    auto ccIncludePaths = findCcIncludePaths();

    if (ccIncludePaths == null)
    {
        auto message = "Unable to check the assertion. cc include paths couldn't be found.";
        stderr.writeln(format("Warning@%s(%d): %s", file, line, message));
        return [];
    }

    return ccIncludePaths ~ gnuStepPath;
}

void assertRunsDStep(
    string expectedPath,
    string actualPath,
    bool strict,
    string[] arguments,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.process : execute;
    import std.path : baseName;
    import std.format : format;
    import clang.Util : namedTempDir;
    import std.file : readText;

    assertFileExists(expectedPath, file, line);
    assertFileExists(actualPath, file, line);

    string outputDir = namedTempDir("dstepUnitTest");
    string outputPath = buildPath(outputDir, baseName(expectedPath));

    scope(exit) rmdirRecurse(outputDir);

    auto command = ["dstep", actualPath] ~ arguments ~ ["-o", outputPath];
    auto result = execute(command);

    auto sep = "----------------";

    if (result.status != 0)
    {
        auto templ = q"/
DStep failed with status %4$d.
%1$s
DStep command:
%2$s
%1$s
DStep output:
%3$s/";

        auto message = format(
            templ,
            sep,
            join(command, " "),
            result.output,
            result.status);

        throw new AssertError(message, file, line);
    }

    if (!exists(outputPath) || !isFile(outputPath))
    {
        auto templ = q"/
Output file `%4$s` doesn't exist.
%1$s
DStep command:
%2$s
%1$s
DStep output:
%3$s/";

        auto message = format(
            templ,
            sep,
            join(command, " "),
            result.output,
            outputPath);

        throw new AssertError(message, file, line);
    }

    string expected = readText(expectedPath);
    string actual = readText(outputPath);

    if (!compareString(expected, actual, strict))
    {
        auto fmt = q"/
Source code translated to:
%1$s
%2$s
%1$s
Expected D code:
%1$s
%3$s
%1$s
DStep command:
%4$s/";

        string commandString = join(command, " ");
        string message = format(fmt, sep, actual, expected, commandString);
        throw new TranslateAssertError(message, file, line);
    }
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
        auto extra = findExtraGNUStepPaths(file, line);

        if (extra.empty)
            return;
        else
            arguments ~= extra;
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

void assertRunsDStepCFile(
    string expectedPath,
    string cPath,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] arguments = ["-Iresources"];

    assertRunsDStep(
        expectedPath,
        cPath,
        strict,
        arguments,
        file,
        line);
}

void assertRunsDStepObjCFile(
    string expectedPath,
    string objCPath,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] arguments = ["-ObjC", "-Iresources"];

    version (linux)
    {
        auto extra = findExtraGNUStepPaths(file, line);

        if (extra.empty)
            return;
        else
            arguments ~= extra;
    }

    assertRunsDStep(
        expectedPath,
        objCPath,
        strict,
        arguments,
        file,
        line);
}
