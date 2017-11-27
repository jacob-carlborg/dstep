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
        "tests/functional/aggregate.d",
        "tests/functional/aggregate.h");

    assertRunsDStepCFile(
        "tests/functional/comments_enabled.d",
        "tests/functional/comments_enabled.h");

    assertRunsDStepCFile(
        "tests/functional/comments_disabled.d",
        "tests/functional/comments_disabled.h",
        ["--comments=false"]);

    assertRunsDStepCFiles([
        TestFile("tests/functional/module/main0.d", "tests/functional/module/main0.h"),
        TestFile("tests/functional/module/include.d", "tests/functional/module/include.h"),
        TestFile("tests/functional/module/unused.d", "tests/functional/module/unused.h")],
        ["--package", "modules"]);

    assertRunsDStepCFiles([
        TestFile("tests/functional/module/main0_public.d", "tests/functional/module/main0_public.h"),
        TestFile("tests/functional/module/include.d", "tests/functional/module/include.h"),
        TestFile("tests/functional/module/unused.d", "tests/functional/module/unused.h")],
        ["--public-submodules", "--package", "modules"]);

    assertRunsDStepCFiles([
        TestFile("tests/functional/module/main0NotNormalized.d", "tests/functional/module/main0NotNormalized.h"),
        TestFile("tests/functional/module/include.d", "tests/functional/module/include.h"),
        TestFile("tests/functional/module/unused.d", "tests/functional/module/unused.h")],
        ["--public-submodules", "--package", "modules"]);

    assertRunsDStepCFiles([
        TestFile("tests/functional/clang-c/BuildSystem.d", "tests/functional/clang-c/BuildSystem.h"),
        TestFile("tests/functional/clang-c/CXCompilationDatabase.d", "tests/functional/clang-c/CXCompilationDatabase.h"),
        TestFile("tests/functional/clang-c/CXErrorCode.d", "tests/functional/clang-c/CXErrorCode.h"),
        TestFile("tests/functional/clang-c/CXString.d", "tests/functional/clang-c/CXString.h"),
        TestFile("tests/functional/clang-c/Documentation.d", "tests/functional/clang-c/Documentation.h"),
        TestFile("tests/functional/clang-c/Index.d", "tests/functional/clang-c/Index.h"),
        TestFile("tests/functional/clang-c/Platform.d", "tests/functional/clang-c/Platform.h")],
        ["-Itests/functional", "--public-submodules", "--normalize-modules", "--package", "clang.c"]);

    assertRunsDStepCFiles(
        [TestFile("tests/functional/multiThreadTest1.d", "tests/functional/multiThreadTest1.h"),
         TestFile("tests/functional/multiThreadTest2.d", "tests/functional/multiThreadTest2.h")]);
}

// DStep should exit with non-zero status when an input file doesn't exist.
unittest
{
    auto result = executeShell(`"./bin/dstep" tests/functional/nonexistent.h`);

    assert(result.status != 0);
    assert(result.output.canFind("nonexistent.h"));
}

// DStep should exit with non-zero status when one of the input files doesn't exist.
unittest
{
    auto result = executeShell(`"./bin/dstep" tests/functional/nonexistent.h tests/functional/existent.h`);

    assert(result.status != 0);
    assert(result.output.canFind("nonexistent.h"));
}

// DStep should exit with non-zero status when there is a syntax error in the input file.
unittest
{
    auto result = executeShell(`"./bin/dstep" tests/functional/syntax_error.h`);

    assert(result.status != 0);
    assert(result.output.canFind("syntax_error.h"));
}

// DStep should exit with zero status when everything is fine.
unittest
{
    auto result = executeShell(`"./bin/dstep" tests/functional/aggregate.h`);

    assert(result.status == 0);
}

// DStep should exit with zero status when asked for help.
unittest
{
    auto result = executeShell(`"./bin/dstep" --help`);

    assert(result.status == 0);
}

// DStep should show help when invoked without arguments.
unittest
{
    auto result = executeShell(`"./bin/dstep"`);

    assert(result.status == 0);
    assert(result.output.canFind("Usage: dstep [options] <input>"));
}

// Test `--objective-c` option.
unittest
{
    assertRunsDStep(
        [TestFile("tests/functional/objc/primitives.d", "tests/functional/objc/primitives.h")],
        ["--objective-c", "-Iresources"],
        false);
}

// Test `--global-import` option.
unittest
{
    assertRunsDStep(
        [TestFile("tests/functional/globalImports.d", "tests/functional/globalImports.h")],
        ["--global-import", "fstImport", "--global-import", "sndImport"],
        false);
}

// DStep should issue a warning when it detects a name collision.
unittest
{
    assertIssuesWarning("tests/functional/collision.h");
}

unittest
{
    assertRunsDStepObjCFile(
        "tests/functional/objc/methods.d",
        "tests/functional/objc/methods.h"
    );
}
