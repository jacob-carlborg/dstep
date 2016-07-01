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

    assertRunsDStepObjCFile(
        "test_files/objc/methods.d",
        "test_files/objc/methods.h");

    assertRunsDStepCFiles(
        [tuple("test_files/multiThreadTest1.d", "test_files/multiThreadTest1.h"),
         tuple("test_files/multiThreadTest2.d", "test_files/multiThreadTest2.h")]);
}
