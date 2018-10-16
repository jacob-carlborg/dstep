/**
 * Copyright: Copyright (c) 2018 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: May 16, 2018
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module tests.unit.main;

shared static this()
{
    import std.stdio : writeln;
    import clang.Util : clangVersionString;

    writeln("with ", clangVersionString);
}
