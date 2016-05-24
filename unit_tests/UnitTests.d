/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import std.stdio;
import Common;
import dstep.translator.Translator;

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

unittest
{
    assertTranslates(
q"C
struct A
{
    struct B
    {
        int x;
    } b;
};
C",
q"D
extern (C):

struct A
{
    struct B
    {
        int x;
    }

    B b;
}
D");
}

unittest
{
    assertTranslates(
q"C
float foo(int x);
float bar(int x);

int a;
C",
q"D
extern (C):

float foo (int x);
float bar (int x);

extern __gshared int a;
D");

}

unittest
{
    assertTranslates(
q"C

#define FOO 4

char var[FOO];
C",
q"D
extern (C):

enum FOO = 4;
extern __gshared char[FOO] var;
D");

    assertTranslates(
q"C

#define BAR 128

struct Foo
{
    char var[BAR];
};
C",
q"D
extern (C):

enum BAR = 128;

struct Foo
{
    char[BAR] var;
}
D");

    assertTranslates(
q"C

#define FOO 64
#define BAR 128
#define BAZ 256

struct Foo
{
    char var[BAR][FOO][BAZ];
    char rav[BAR][BAZ][42];
};
C",
q"D
extern (C):

enum FOO = 64;
enum BAR = 128;
enum BAZ = 256;

struct Foo
{
    char[BAZ][FOO][BAR] var;
    char[42][BAZ][BAR] rav;
}
D");

}
