/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 26, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import std.stdio;
import Common;
import dstep.translator.Translator;


// Test a nested struct.
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

// Test translation of a nested anonymous structures.
unittest
{
    assertTranslates(q"C
struct C
{
    union {
        int x;
        int y;
    };

    struct {
        int z;
        int w;

        union {
            int r, g, b;
        };
    };
};
C",
q"D
extern (C):

struct C
{
    union
    {
        int x;
        int y;
    }

    struct
    {
        int z;
        int w;

        union
        {
            int r;
            int g;
            int b;
        }
    }
}
D");

}

// Test packed structures.
unittest
{
    assertTranslates(
q"C

typedef struct __attribute__((__packed__)) { } name;

struct Foo
{
	char x;
	short y;
	int z;
} __attribute__((__packed__));

C",
q"D
extern (C):

struct name
{
    align (1):
}

struct Foo
{
    align (1):

    char x;
    short y;
    int z;
}

D");

}
