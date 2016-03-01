/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import std.stdio;
import Common;

unittest
{
    assertTranslates(
        "#define SOME_INTEGER 0", 
        "extern (C):\n\nenum SOME_INTEGER = 0;");
}

unittest
{
    assertTranslates(
        "#define FOO 0\n#define BAR 1\n", 
        "extern (C):\n\nenum FOO = 0;\nenum BAR = 1;");
}

unittest
{
	assertTranslates(
        "#define SOME_STRING \"foobar\"", 
        "extern (C):\n\nenum SOME_STRING = \"foobar\";");	
}
