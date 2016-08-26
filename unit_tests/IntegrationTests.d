/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Apr 08, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import Common;

import std.algorithm : canFind;
import std.process : executeShell;
import std.typecons;

unittest
{
    assertRunsDStepCFile(
        "test_files/aggregate.d",
        "test_files/aggregate.h");

    assertRunsDStepCFile(
        "test_files/comments_enabled.d",
        "test_files/comments_enabled.h");

    assertRunsDStepCFile(
        "test_files/comments_disabled.d",
        "test_files/comments_disabled.h",
        ["--comments=false"]);

    assertRunsDStepCFiles([
        TestFile("test_files/module/main0.d", "test_files/module/main0.h"),
        TestFile("test_files/module/include.d", "test_files/module/include.h"),
        TestFile("test_files/module/unused.d", "test_files/module/unused.h")],
        ["--package", "modules"]);

    assertRunsDStepCFiles([
        TestFile("test_files/module/main0_public.d", "test_files/module/main0_public.h"),
        TestFile("test_files/module/include.d", "test_files/module/include.h"),
        TestFile("test_files/module/unused.d", "test_files/module/unused.h")],
        ["--public-submodules", "--package", "modules"]);

    assertRunsDStepCFiles([
        TestFile("test_files/clang-c/BuildSystem.d", "test_files/clang-c/BuildSystem.h"),
        TestFile("test_files/clang-c/CXCompilationDatabase.d", "test_files/clang-c/CXCompilationDatabase.h"),
        TestFile("test_files/clang-c/CXErrorCode.d", "test_files/clang-c/CXErrorCode.h"),
        TestFile("test_files/clang-c/CXString.d", "test_files/clang-c/CXString.h"),
        TestFile("test_files/clang-c/Documentation.d", "test_files/clang-c/Documentation.h"),
        TestFile("test_files/clang-c/Index.d", "test_files/clang-c/Index.h"),
        TestFile("test_files/clang-c/Platform.d", "test_files/clang-c/Platform.h")],
        ["-Itest_files", "--public-submodules", "--package", "clang.c"]);

    assertRunsDStepObjCFile(
        "test_files/objc/methods.d",
        "test_files/objc/methods.h");

    assertRunsDStepCFiles(
        [TestFile("test_files/multiThreadTest1.d", "test_files/multiThreadTest1.h"),
         TestFile("test_files/multiThreadTest2.d", "test_files/multiThreadTest2.h")]);
}

// DStep should exit with non-zero status when an input file doesn't exist.
unittest
{
    auto result = executeShell(`"./bin/dstep" test_files/nonexistent.h`);

    assert(result.status != 0);
    assert(result.output.canFind("nonexistent.h"));
}

// DStep should exit with non-zero status when one of the input files doesn't exist.
unittest
{
    auto result = executeShell(`"./bin/dstep" test_files/nonexistent.h test_files/existent.h`);

    assert(result.status != 0);
    assert(result.output.canFind("nonexistent.h"));
}

// DStep should exit with non-zero status when there is a syntax error in the input file.
unittest
{
    auto result = executeShell(`"./bin/dstep" test_files/syntax_error.h`);

    assert(result.status != 0);
    assert(result.output.canFind("syntax_error.h"));
}

// DStep should exit with zero status when everything is fine.
unittest
{
    auto result = executeShell(`"./bin/dstep" test_files/aggregate.h`);

    assert(result.status == 0);
}

// DStep should exit with zero status when asked for help.
unittest
{
    auto result = executeShell(`"./bin/dstep" --help`);

    assert(result.status == 0);
}

// Test `--objective-c` option.
unittest
{
    assertRunsDStep(
        [TestFile("test_files/objc/primitives.d", "test_files/objc/primitives.h")],
        ["--objective-c", "-Iresources"],
        false);
}
