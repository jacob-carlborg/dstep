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

import dstep.translator.CommentIndex;
import dstep.translator.Context;
import dstep.translator.IncludeHandler;
import dstep.translator.MacroDefinition;
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

TranslationUnit makeTranslationUnit(string source)
{
    return TranslationUnit.parseString(
        index,
        source,
        ["-Wno-missing-declarations"],
        null,
        CXTranslationUnit_Flags.CXTranslationUnit_DetailedPreprocessingRecord);
}

CommentIndex makeCommentIndex(string c)
{
    TranslationUnit translUnit = makeTranslationUnit(c);
    return new CommentIndex(translUnit);
}

MacroDefinition parseMacroDefinition(string source)
{
    import dstep.translator.MacroDefinition : parseMacroDefinition;

    TokenRange tokenize(string source)
    {
        auto translUnit = makeTranslationUnit(source);
        return translUnit.tokenize(translUnit.extent(0, cast(uint) source.length));
    }

    TokenRange tokens = tokenize(source);

    Cursor[string] dummy;

    return parseMacroDefinition(tokens, dummy);
}

void assertCollectsTypeNames(string[] expected, string source, string file = __FILE__, size_t line = __LINE__)
{
    import std.format : format;

    auto translUnit = makeTranslationUnit(source);
    auto names = collectGlobalTypes(translUnit);

    foreach (name; expected)
    {
        if ((name in names) is null)
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
    this (string message, string file, ulong line)
    {
        super(message, file, line);
    }
}

void assertTranslates(
    string expected,
    TranslationUnit unit,
    Options options,
    bool strict,
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

    auto translated = translate(unit, options);

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
            translated = translated[0 .. maxSubmessageLength] ~ "...";

        if (maxSubmessageLength < astDump.length)
            astDump = astDump[0 .. maxSubmessageLength] ~ "...";

        string message = format(fmt, sep, translated, expected, astDump);
        throw new TranslateAssertError(message, file, line);
    }
}

void assertTranslates(
    string c,
    string d,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    auto unit = makeTranslationUnit(c);
    Options options;
    options.language = Language.c;
    assertTranslates(d, unit, options, strict, file, line);
}

void assertTranslates(
    string c,
    string d,
    Options options,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    auto unit = makeTranslationUnit(c);
    assertTranslates(d, unit, options, strict, file, line);
}

void assertTranslatesFile(
    string expectedPath,
    string actualPath,
    Options options,
    bool strict,
    string[] arguments,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.file : readText;

    auto expected = readText(expectedPath);
    auto unit = TranslationUnit.parse(index, actualPath, arguments);
    assertTranslates(expected, unit, options, strict, file, line);
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
    string[] arguments,
    bool strict,
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
    Options options = Options.init,
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] arguments = ["-Iresources"];

    options.language = Language.c;

    assertTranslatesFile(
        expectedPath,
        cPath,
        options,
        strict,
        arguments,
        file,
        line);
}

void assertTranslatesObjCFile(
    string expectedPath,
    string objCPath,
    Options options = Options.init,
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

    options.language = Language.objC;

    assertTranslatesFile(
        expectedPath,
        objCPath,
        options,
        strict,
        arguments,
        file,
        line);
}

void assertRunsDStepCFile(
    string expectedPath,
    string cPath,
    string[] arguments = [],
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] extended = arguments ~ ["-Iresources"];

    assertRunsDStep(
        [tuple(expectedPath, cPath)],
        extended,
        strict,
        file,
        line);
}

void assertRunsDStepObjCFile(
    string expectedPath,
    string objCPath,
    string[] arguments = [],
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] extended = arguments ~ ["-ObjC", "-Iresources"];

    version (linux)
    {
        auto extra = findExtraGNUStepPaths(file, line);

        if (extra.empty)
            return;
        else
            extended ~= extra;
    }

    assertRunsDStep(
        [tuple(expectedPath, objCPath)],
        extended,
        strict,
        file,
        line);
}

void assertRunsDStepCFiles(
    Tuple!(string, string)[] filesPaths,
    string[] arguments = [],
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] extended = arguments ~ ["-Iresources"];

    assertRunsDStep(
        filesPaths,
        extended,
        strict,
        file,
        line);
}
