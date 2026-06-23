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

static IncludeGraph makeIncludeGraph(string sourceFilename)
{
    return new IncludeGraph(makeTranslationUnitFromFile(sourceFilename));
}

unittest
{
    const string file = "tests/functional/graph/file.h".asAbsNormPath();
    const string subfile1 = "tests/functional/graph/subfile1.h".asAbsNormPath();
    const string subfile2 = "tests/functional/graph/subfile2.h".asAbsNormPath();
    const string subfile3 = "tests/functional/graph/subfile3.h".asAbsNormPath();
    const string subsubfile1 = "tests/functional/graph/subsubfile1.h".asAbsNormPath();
    const string subsubfile2 = "tests/functional/graph/subsubfile2.h".asAbsNormPath();
    const string subsubfile3 = "tests/functional/graph/subsubfile3.h".asAbsNormPath();

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

    auto translationUnit = makeTranslationUnitFromFile(
        "tests/functional/clang-c/Index.h",
        ["-Wno-missing-declarations", "-Itests/functional"]);
    auto headerIndex = new HeaderIndex(translationUnit);

    auto timeT = translationUnit.cursor.children.filter!(x => x.spelling == "time_t").front;

    assert(headerIndex.searchKnownModules(timeT) == "core.stdc.time");
}

unittest
{
    auto translationUnit = makeTranslationUnitFromFile(
        "tests/functional/graph/self_including_main.h",
        ["-Wno-missing-declarations", "-Itests/functional"]);

    new HeaderIndex(translationUnit);
}
