/**
 * Copyright: Copyright (c) 2018 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: January 05, 2019
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

unittest
{
    assertTranslates(
    q"C
typedef unsigned short ushort;
typedef unsigned char byte;

typedef byte (*data_in) 	(int param, ushort address);
typedef void (*data_out)	(int param, ushort address, byte data);

typedef struct
{
	ushort PC;
	byte IM;
} foo;
C",
    q"D
extern (C):

alias data_in = ubyte function (int param, ushort address);
alias data_out = void function (int param, ushort address, ubyte data);

struct foo
{
    ushort PC;
    ubyte IM;
}
D");
}
