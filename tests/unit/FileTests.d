/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Mar 12, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import Common;
import dstep.translator.Translator;

unittest
{
    assertTranslatesCFile(
        "tests/functional/aggregate.d",
        "tests/functional/aggregate.h");
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/arrays.d",
        "tests/functional/arrays.h");
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/comments.d",
        "tests/functional/comments.h");
}

unittest
{
    Options options;
    options.enableComments = false;

    assertTranslatesCFile(
        "tests/functional/const.d",
        "tests/functional/const.h",
        options);
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/enums.d",
        "tests/functional/enums.h");
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/function_pointers.d",
        "tests/functional/function_pointers.h");
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/functions.d",
        "tests/functional/functions.h");
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/include.d",
        "tests/functional/include.h");
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/preprocessor.d",
        "tests/functional/preprocessor.h");
}

unittest
{
    Options options;
    options.enableComments = false;

    assertTranslatesCFile(
        "tests/functional/primitives.d",
        "tests/functional/primitives.h",
        options);
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/structs.d",
        "tests/functional/structs.h");
}

unittest
{
    Options options;
    options.reduceAliases = false;

    assertTranslatesCFile(
        "tests/functional/typedef.d",
        "tests/functional/typedef.h",
        options);
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/typedef_struct.d",
        "tests/functional/typedef_struct.h");
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/unions.d",
        "tests/functional/unions.h");
}

unittest
{
    assertTranslatesCFile(
        "tests/functional/variables.d",
        "tests/functional/variables.h");
}
