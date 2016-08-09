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

// Translate immediately declared array variable in global scope.
unittest
{
    assertTranslates(
q"C

struct Bar {
const char *foo;
const char *oof;
} baz[64];

C",
q"D
extern (C):

struct Bar
{
    const(char)* foo;
    const(char)* oof;
}

extern __gshared Bar[64] baz;
D");

}

// Do not put an extra newline after array declaration.
unittest
{
    assertTranslates(q"C
struct Foo {
    int data[32];
    char len;
};
C",
q"D
extern (C):

struct Foo
{
    int[32] data;
    char len;
}
D");

}

// Translate nested structure with immediate array variable.
unittest
{
    assertTranslates(q"C
struct Foo {
  struct Bar {
    const char *qux0;
    const char *qux1;
  } baz[64];
};
C",
q"D
extern (C):

struct Foo
{
    struct Bar
    {
        const(char)* qux0;
        const(char)* qux1;
    }

    Bar[64] baz;
}
D");

    // Anonymous variant.
    assertTranslates(q"C
struct Foo {
  struct {
    const char *qux;
  } baz[64];
};
C",
q"D
extern (C):

struct Foo
{
    struct _Anonymous_0
    {
        const(char)* qux;
    }

    _Anonymous_0[64] baz;
}
D");

}

// Translate nested structure with immediate pointer variable.
unittest
{
     assertTranslates(q"C
struct Foo {
  struct Bar {
  } *baz;
};
C",
q"D
extern (C):

struct Foo
{
    struct Bar
    {
    }

    Bar* baz;
}
D");

    assertTranslates(q"C
struct Foo {
  struct {
  } *baz;
};
C",
q"D
extern (C):

struct Foo
{
    struct _Anonymous_0
    {
    }

    _Anonymous_0* baz;
}

D");

    // Multiple pointers.
    assertTranslates(q"C
struct Foo {
  struct {
  } **baz;
};
C",
q"D
extern (C):

struct Foo
{
    struct _Anonymous_0
    {
    }

    _Anonymous_0** baz;
}

D");

}
