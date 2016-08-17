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
import clang.Diagnostic;

import dstep.driver.Application;
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

string mismatchRegion(
    string expected,
    string actual,
    size_t margin,
    bool strict,
    string prefix = "<<<<<<< expected",
    string interfix = "=======",
    string suffix = ">>>>>>> actual")
{
    import std.algorithm.iteration : splitter;
    import std.string : lineSplitter, stripRight;
    import std.algorithm.comparison : min;

    if (!strict)
    {
        expected = stripRight(expected);
        actual = stripRight(actual);
    }

    string Q[];
    size_t q = 0;
    size_t p = 0;
    Q.length = margin;

    size_t line = 0;

    auto aItr = lineSplitter(expected);
    auto bItr = lineSplitter(actual);

    while (!aItr.empty && !bItr.empty)
    {
        if (aItr.front != bItr.front)
            break;

        Q[p] = aItr.front;

        q = min(q + 1, margin);
        p = (p + 1) % margin;

        aItr.popFront();
        bItr.popFront();

        ++line;
    }

    if (strict && expected.length != actual.length && aItr.empty && bItr.empty)
    {
        if (expected.length < actual.length)
            bItr = lineSplitter("\n");
        else
            aItr = lineSplitter("\n");
    }

    if (!aItr.empty || !bItr.empty)
    {
        import std.array : Appender;
        import std.conv : to;

        auto result = Appender!string();

        auto l = line - q;

        result.put(prefix);
        result.put("\n");

        foreach (i; 0 .. q)
        {
            result.put(to!string(l + i));
            result.put(": ");
            result.put(Q[(p + i) % q]);
            result.put("\n");
        }

        for (size_t i = 0; i <= margin && !aItr.empty; ++i)
        {
            result.put(to!string(line + i));
            result.put("> ");
            result.put(aItr.front);
            result.put("\n");
            aItr.popFront();
        }

        result.put(interfix);
        result.put("\n");

        foreach (i; 0 .. q)
        {
            result.put(to!string(l + i));
            result.put(": ");
            result.put(Q[(p + i) % q]);
            result.put("\n");
        }

        for (size_t i = 0; i <= margin && !bItr.empty; ++i)
        {
            result.put(to!string(line + i));
            result.put("> ");
            result.put(bItr.front);
            result.put("\n");
            bItr.popFront();
        }

        result.put(suffix);
        result.put("\n");

        return result.data;
    }

    return null;
}

string mismatchRegionTranslated(
    string translated,
    string expected,
    size_t margin,
    bool strict)
{
    return mismatchRegion(
        translated,
        expected,
        margin,
        strict,
        "Translated code doesn't match expected.\n<<<<<<< translated",
        "=======",
        ">>>>>>> expected");
}

unittest
{
    void assertMismatchRegion(
        string expected,
        string a,
        string b,
        bool strict = false,
        size_t margin = 2,
        string file = __FILE__,
        size_t line = __LINE__)
    {
        import std.format;

        auto actual = mismatchRegion(a, b, margin, strict);

        if (expected != actual)
        {
            auto templ = "\nExpected:\n%s\nActual:\n%s\n";

            string message = format(templ, expected, actual);

            throw new AssertError(message, file, line);
        }
    }

    assertMismatchRegion(null, "", "");

    assertMismatchRegion(null, "foo", "foo");

    assertMismatchRegion(q"X
<<<<<<< expected
0: foo
1> bar
=======
0: foo
1> baz
>>>>>>> actual
X", "foo\nbar", "foo\nbaz");

    assertMismatchRegion(q"X
<<<<<<< expected
0: foo
=======
0: foo
1> baz
>>>>>>> actual
X", "foo", "foo\nbaz");

    assertMismatchRegion(q"X
<<<<<<< expected
1: bar
2: baz
3> quuux
4> yada
5> yada
=======
1: bar
2: baz
3> quux
4> yada
5> yada
>>>>>>> actual
X", "foo\nbar\nbaz\nquuux\nyada\nyada\nyada\nlast", "foo\nbar\nbaz\nquux\nyada\nyada\nyada\nlast");

    assertMismatchRegion(q"X
<<<<<<< expected
1: bar
2: baz
3> quuux
4> yada
5> yada
=======
1: bar
2: baz
3> quuuux
4> yada
5> yada
>>>>>>> actual
X", "foo\nbar\nbaz\nquuux\nyada\nyada\nyada\nlast", "foo\nbar\nbaz\nquuuux\nyada\nyada\nyada\nlast");

    assertMismatchRegion(
        "<<<<<<< expected\n0: foo\n1> \n=======\n0: foo\n>>>>>>> actual\n",
        "foo\n",
        "foo",
        true);
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

bool fileExists(string path)
{
    import std.file : exists, isFile;
    return exists(path) && isFile(path);
}

void assertFileExists(
    string expected,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.format : format;

    if (!fileExists(expected))
    {
        auto message = format("File %s doesn't exist.", expected);
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
    import dstep.translator.MacroDefinition : parseMacroDefinition;

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

    auto translated = translate(translUnit, options);
    auto mismatch = mismatchRegionTranslated(translated, expected, 5, strict);

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

void assertTranslatesFile(
    string expectedPath,
    string actualPath,
    Options options,
    bool strict,
    string[] arguments,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import clang.Util : asAbsNormPath;
    import std.file : readText;

    arguments ~= findExtraIncludePaths();

    auto expected = readText(expectedPath);
    auto translUnit = TranslationUnit.parse(index, actualPath, arguments);

    if (options.inputFile.empty)
        options.inputFile = translUnit.spelling.asAbsNormPath;

    assertTranslates(expected, translUnit, options, strict, file, line);
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

string[] extractIncludePaths(string output)
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

string[] findCcIncludePaths()
{
    import std.process : executeShell;
    auto result = executeShell("cc -E -v - < /dev/null");

    if (result.status == 0)
        return extractIncludePaths(result.output);
    else
        return null;
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

struct TestFile
{
    string expected;
    string actual;
}

void assertRunsDStep(
    TestFile[] filesPaths,
    string[] arguments,
    bool strict,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.process : execute;
    import std.path : baseName;
    import std.format : format;
    import clang.Util : namedTempDir;
    import std.file : readText, mkdirRecurse, copy;

    arguments ~= findExtraIncludePaths();

    string[] actualPaths;

    foreach (filesPath; filesPaths)
    {
        assertFileExists(filesPath.actual, file, line);    //Actual Paths
        actualPaths ~= filesPath.actual;
    }

    string outputDir = namedTempDir("dstepUnitTest");

    string[] outputPaths;

    if (filesPaths.length == 1)
        outputPaths ~= buildPath(outputDir,
            Application.defaultOutputFilename(filesPaths[0].expected, false));
    else
    {
        foreach (filesPath; filesPaths)
            outputPaths ~= buildPath(outputDir,
                Application.defaultOutputFilename(filesPath.expected, false));
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

        if (fileExists(filesPaths[i].expected))
        {
            string expected = readText(filesPaths[i].expected);
            string actual = readText(outputPath);

            auto mismatch = mismatchRegionTranslated(actual, expected, 5, strict);

            if (mismatch)
            {
                string commandString = join(command, " ");

                string message = format("\n%s\nDStep command:\n%s", mismatch, commandString);

                throw new AssertError(message, file, line);
            }
        }
        else
        {
            copy(outputPath, filesPaths[i].expected);
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

    version (OptionalGNUStep)
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
        [TestFile(expectedPath, cPath)],
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

    version (OptionalGNUStep)
    {
        auto extra = findExtraGNUStepPaths(file, line);

        if (extra.empty)
            return;
        else
            extended ~= extra;
    }

    assertRunsDStep(
        [TestFile(expectedPath, objCPath)],
        extended,
        strict,
        file,
        line);
}

void assertRunsDStepCFiles(
    TestFile[] filesPaths,
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
