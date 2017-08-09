/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: September 18, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import Common;

import clang.c.Index;
import clang.Compiler;
import clang.Index;
import clang.TranslationUnit;
import clang.Util;

import dstep.translator.HeaderIndex;

static TranslationUnit makeTranslationUnit(
    string sourceFilename,
    const string[] commandLineArgs = ["-Wno-missing-declarations"],
    uint options = CXTranslationUnit_Flags.detailedPreprocessingRecord)
{
    import std.algorithm;
    import std.array;

    Compiler compiler;

    auto includeFlags = compiler
        .extraIncludePaths.map!(e => "-I" ~ e).array();

    auto index = Index(false, false);

    return TranslationUnit.parse(
        index,
        sourceFilename,
        commandLineArgs ~ includeFlags,
        compiler.extraHeaders,
        options);
}

static IncludeGraph makeIncludeGraph(string sourceFilename)
{
    return new IncludeGraph(makeTranslationUnit(sourceFilename));
}

unittest
{
    const string file = "test_files/graph/file.h".asAbsNormPath();
    const string subfile1 = "test_files/graph/subfile1.h".asAbsNormPath();
    const string subfile2 = "test_files/graph/subfile2.h".asAbsNormPath();
    const string subfile3 = "test_files/graph/subfile3.h".asAbsNormPath();
    const string subsubfile1 = "test_files/graph/subsubfile1.h".asAbsNormPath();
    const string subsubfile2 = "test_files/graph/subsubfile2.h".asAbsNormPath();
    const string subsubfile3 = "test_files/graph/subsubfile3.h".asAbsNormPath();

    auto includeGraph = makeIncludeGraph(file);

    // The file is reachable by itself.
    assert(includeGraph.isReachableBy(file, file));
    assert(includeGraph.isReachableBy(subfile3, subfile3));

    // The file is reachable by its direct includer.
    assert(includeGraph.isReachableBy(subfile2, file));

    // The file is reachable by its indirect includer.
    assert(includeGraph.isReachableBy(subsubfile3, file));

    // The file isn't reachable by unrelated file.
    assert(!includeGraph.isReachableBy(subsubfile3, subfile1));

    // The inclusion cannot be reversed.
    assert(!includeGraph.isReachableBy(file, subsubfile3));
}

unittest
{
    import std.algorithm;

    auto translationUnit = makeTranslationUnit(
        "test_files/clang-c/Index.h",
        ["-Wno-missing-declarations", "-Itest_files"]);

    auto headerIndex = new HeaderIndex(translationUnit);

    auto timeT = translationUnit.cursor.children.filter!(x => x.spelling == "time_t").front;

    assert(headerIndex.searchKnownModules(timeT) == "core.stdc.time");
}

unittest
{
    auto translationUnit = makeTranslationUnit(
        "test_files/graph/self_including_main.h",
        ["-Wno-missing-declarations", "-Itest_files"]);

    new HeaderIndex(translationUnit);
}
