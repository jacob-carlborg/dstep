/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Mar 12, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;
import dstep.translator.CodeBlock;
import dstep.translator.Translator;

unittest
{
    assertTranslatesObjCFile(
        "test_files/objc/categories.d",
        "test_files/objc/categories.h");
}

unittest
{
    assertTranslatesObjCFile(
        "test_files/objc/classes.d",
        "test_files/objc/classes.h");
}

unittest
{
    assertTranslatesObjCFile(
        "test_files/objc/methods.d",
        "test_files/objc/methods.h");
}

unittest
{
    assertTranslatesObjCFile(
        "test_files/objc/primitives.d",
        "test_files/objc/primitives.h");
}

unittest
{
    assertTranslatesObjCFile(
        "test_files/objc/properties.d",
        "test_files/objc/properties.h");
}

unittest
{
    assertTranslatesObjCFile(
        "test_files/objc/protocols.d",
        "test_files/objc/protocols.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/aggregate.d",
        "test_files/aggregate.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/arrays.d",
        "test_files/arrays.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/const.d",
        "test_files/const.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/enums.d",
        "test_files/enums.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/function_pointers.d",
        "test_files/function_pointers.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/functions.d",
        "test_files/functions.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/include.d",
        "test_files/include.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/preprocessor.d",
        "test_files/preprocessor.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/primitives.d",
        "test_files/primitives.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/structs.d",
        "test_files/structs.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/typedef.d",
        "test_files/typedef.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/typedef_struct.d",
        "test_files/typedef_struct.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/unions.d",
        "test_files/unions.h");
}

unittest
{
    assertTranslatesCFile(
        "test_files/variables.d",
        "test_files/variables.h");
}
