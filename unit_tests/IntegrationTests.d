/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Apr 08, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import Common;
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
        ["--no-comments"]);

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
        ["-Itest_files", "--package", "clang.c"]);

    assertRunsDStepObjCFile(
        "test_files/objc/methods.d",
        "test_files/objc/methods.h");

    assertRunsDStepCFiles(
        [TestFile("test_files/multiThreadTest1.d", "test_files/multiThreadTest1.h"),
         TestFile("test_files/multiThreadTest2.d", "test_files/multiThreadTest2.h")]);
}
