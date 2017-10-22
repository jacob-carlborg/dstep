/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: October 22, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
 module tests.unit.BitFieldsTests;

import Common;

unittest
{
    assertTranslates(q"C
struct Foo
{
    int x : 4;
};

C",q"D
extern (C):

struct Foo
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        int, "x", 4,
        uint, "", 4));
}
D");

}

unittest
{
    assertTranslates(q"C
struct Foo
{
    int x : 8;
};

C",q"D
extern (C):

struct Foo
{
    import std.bitmanip : bitfields;
    mixin(bitfields!(int, "x", 8));
}
D");

}


unittest
{
    assertTranslates(q"C
struct bitfield {
    unsigned int one : 4;
    unsigned int two : 8;
    unsigned int : 4;
};
C",q"D
extern (C):

struct bitfield
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        uint, "one", 4,
        uint, "two", 8,
        uint, "", 4));
}
D");
}

unittest
{
    assertTranslates(q"C
struct Foo {
    unsigned char a : 3, : 2, b : 6, c : 2;
};
C",q"D
extern (C):

struct Foo
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        ubyte, "a", 3,
        ubyte, "", 2,
        ubyte, "b", 6,
        ubyte, "c", 2,
        uint, "", 3));
}
D");

};

unittest
{
    assertTranslates(q"C
struct Foo {
    short a : 4;
    char b;
};
C",q"D
extern (C):

struct Foo
{
    import std.bitmanip : bitfields;

    mixin(bitfields!(
        short, "a", 4,
        uint, "", 4));

    char b;
}
D");

};

unittest
{
    assertTranslates(q"C
struct Foo {
    short a;
    char b : 7;
    char c[1];
};
C",q"D
extern (C):

struct Foo
{
    import std.bitmanip : bitfields;

    short a;

    mixin(bitfields!(
        char, "b", 7,
        uint, "", 1));

    char[1] c;
}
D");

};

unittest
{
    assertTranslates(q"C
struct Foo {
    short a;
    char b;
    int c : 1;
    int d : 4;
    int e : 7;
};
C",q"D
extern (C):

struct Foo
{
    import std.bitmanip : bitfields;

    short a;
    char b;

    mixin(bitfields!(
        int, "c", 1,
        int, "d", 4,
        int, "e", 7,
        uint, "", 4));
}
D");

};

unittest
{
    assertTranslates(q"C
struct Foo {
    short a;
    int b : 1;
    int c : 4;
    int d : 3;
    int e : 7;
    int f : 25;
    char g;
};
C",q"D
extern (C):

struct Foo
{
    import std.bitmanip : bitfields;

    short a;

    mixin(bitfields!(
        int, "b", 1,
        int, "c", 4,
        int, "d", 3,
        int, "e", 7,
        int, "f", 25,
        uint, "", 24));

    char g;
}
D");

};

unittest
{
    assertTranslates(q"C
struct Foo {
    short a;
    int b : 1;
    int c : 4;
    int d : 3;
    long e;
    int f : 7;
    int g : 25;
    char h;
};
C",q"D
import core.stdc.config;

extern (C):

struct Foo
{
    import std.bitmanip : bitfields;

    short a;

    mixin(bitfields!(
        int, "b", 1,
        int, "c", 4,
        int, "d", 3));

    c_long e;

    mixin(bitfields!(
        int, "f", 7,
        int, "g", 25));

    char h;
}
D");

};
