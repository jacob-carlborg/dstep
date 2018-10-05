/**
 * Copyright: Copyright (c) 2018 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: October 03, 2018
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

unittest
{
		assertTranslates(
    q"C
typedef struct
{
} BOARDINFO, *PBOARDINFO;
C", q"D
extern (C):

struct BOARDINFO
{
}

alias PBOARDINFO = BOARDINFO*;
D");

    assertTranslates(
    q"C
typedef struct
{
  char          SerNo[12];
  char          ID[20];
  char          Version[10];
  char          Date[12];
  unsigned char Select;
  unsigned char Type;
  char          Reserved[8];
} BOARDINFO, *PBOARDINFO;
C", q"D
extern (C):

struct BOARDINFO
{
    char[12] SerNo;
    char[20] ID;
    char[10] Version;
    char[12] Date;
    ubyte Select;
    ubyte Type;
    char[8] Reserved;
}

alias PBOARDINFO = BOARDINFO*;
D");

}

