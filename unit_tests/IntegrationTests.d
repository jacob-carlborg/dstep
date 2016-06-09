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
        tuple("test_files/module/main0.d", "test_files/module/main0.h"),
        tuple("test_files/module/include.d", "test_files/module/include.h"),
        tuple("test_files/module/unused.d", "test_files/module/unused.h")],
        ["--package", "modules"]);

    assertRunsDStepCFiles([
        tuple("test_files/module/main0_public.d", "test_files/module/main0_public.h"),
        tuple("test_files/module/include.d", "test_files/module/include.h"),
        tuple("test_files/module/unused.d", "test_files/module/unused.h")],
        ["--public-submodules", "--package", "modules"]);


    assertRunsDStepObjCFile(
        "test_files/objc/methods.d",
        "test_files/objc/methods.h");

    assertRunsDStepCFiles(
        [tuple("test_files/multiThreadTest1.d", "test_files/multiThreadTest1.h"),
         tuple("test_files/multiThreadTest2.d", "test_files/multiThreadTest2.h")]);
}
