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
        return format("-I%s", path);
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
    Tuple!(string, string)[] filesPaths,
    bool strict,
    string[] arguments,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.process : execute;
    import std.path : baseName;
    import std.format : format;
    import clang.Util : namedTempDir;
    import std.file : readText, mkdirRecurse;

    string[] actualPaths;

    foreach (Tuple!(string, string) filesPath; filesPaths)
    {
        assertFileExists(filesPath[0], file, line);    //Expected Paths
        assertFileExists(filesPath[1], file, line);    //Actual Paths
        actualPaths ~= filesPath[1];
    }

    string outputDir = namedTempDir("dstepUnitTest");

    string[] outputPaths;
    if (filesPaths.length == 1)
        outputPaths ~= buildPath(outputDir, baseName(filesPaths[0][0]));
    else
    {
        foreach (Tuple!(string, string) filesPath; filesPaths)
        {
            outputPaths ~= buildPath(outputDir, baseName(filesPath[0]));
        }
    }

    scope(exit) rmdirRecurse(outputDir);

    auto command = ["./bin/dstep"] ~ actualPaths ~ arguments;
    if (outputPaths.length == 1)
        command ~= ["-o", outputPaths[0]];
    else
        command ~= ["-o", outputDir];
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

    foreach (i, outputPath; outputPaths)
    {
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

        string expected = readText(filesPaths[i][0]);
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
        [tuple(expectedPath, cPath)],
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
        [tuple(expectedPath, objCPath)],
        strict,
        arguments,
        file,
        line);
}

void assertRunsDStepCFiles(
    Tuple!(string, string)[] filesPaths,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] arguments = ["-Iresources"];

    assertRunsDStep(
        filesPaths,
        strict,
        arguments,
        file,
        line);
}
