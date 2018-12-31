/**
 * Copyright: Copyright (c) 2018 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: September 29, 2018
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

unittest
{
    assertTranslates(
    q"C
#define IsUpper(c) ((0101 <= (c) && (c) <= 0132))
#define IsLower(c) ((0141 <= (c) && (c) <= 0172))
#define ToLower(c) (IsUpper(c) ? (c) - 0101 + 0141 : (c))
C", q"D
extern (C):

extern (D) auto IsUpper(T)(auto ref T c)
{
    import std.conv : octal;

    return (octal!101 <= c && c <= octal!132);
}

extern (D) auto IsLower(T)(auto ref T c)
{
    import std.conv : octal;

    return (octal!141 <= c && c <= octal!172);
}

extern (D) auto ToLower(T)(auto ref T c)
{
    import std.conv : octal;

    return IsUpper(c) ? c - octal!101 + octal!141 : c;
}
D");

}
