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
    int x : 4;
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
    int x : 8;
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
    uint one : 4;
    uint two : 8;
    uint : 4;
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
    ubyte a : 3;
    ubyte : 2;
    ubyte b : 6;
    ubyte c : 2;
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
    short a : 4;

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
    short a;
    char b : 7;

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
    short a;
    char b;
    int c : 1;
    int d : 4;
    int e : 7;
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
    short a;
    int b : 1;
    int c : 4;
    int d : 3;
    int e : 7;
    int f : 25;

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
    short a;
    int b : 1;
    int c : 4;
    int d : 3;

    c_long e;
    int f : 7;
    int g : 25;

    char h;
}
D");

};

unittest
{
    assertTranslates(q"C
struct Foo {
    unsigned int a : 16;
    unsigned int b : 16;
    unsigned int c : 8;
    unsigned int d : 8;
    unsigned int e : 16;
    unsigned long long f : 42;
};
C",q"D
extern (C):

struct Foo
{
    uint a : 16;
    uint b : 16;
    uint c : 8;
    uint d : 8;
    uint e : 16;
    ulong f : 42;
}
D");

}

unittest
{
    assertTranslates(q"C
struct Foo {
    int a : 4;
    int b : 8;
    int c : 12;
};
C",q"D
extern (C):

struct Foo
{
    int a : 4;
    int b : 8;
    int c : 12;
}
D");

}

unittest
{
    assertTranslates(q"C
struct Foo {
    int a : 1;
    int b : 1;
    int c : 1;
    int d : 1;
};
C",q"D
extern (C):

struct Foo
{
    int a : 1;
    int b : 1;
    int c : 1;
    int d : 1;
}
D");

}

// Known limitation that layout won't match C
// Incredibly complex to get this right so leaving like this
unittest
{
    assertTranslates(q"C
struct Foo
{
    __int128 a : 50;
    int b : 10;
    __int128 c : 62;
};
C",q"D
import core.int128;

extern (C):

struct Foo
{
    Cent a; // only 50 bits used, struct's layout incompatible with C
    int b : 10;
    Cent c; // only 62 bits used, struct's layout incompatible with C
}
D");

}
