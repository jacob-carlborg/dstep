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

// Do not put extra end-line after a struct.
unittest
{
    assertTranslates(
q"C
struct Foo {

};
C",
q"D
extern (C):

struct Foo
{
}
D", true);

}

// Remove excessive newlines.
unittest
{
    assertTranslates(
q"C
int a;


int b;


/* Comment, comment. */


/* Comment, comment. */
C",
q"D
extern (C):

extern __gshared int a;

extern __gshared int b;

/* Comment, comment. */

/* Comment, comment. */
D");

}

// Handle // comments.
unittest
{
    assertTranslates(
q"C
int a; // This is inline comment 1.
int b; // This is inline comment 2.

struct X {
    int field; // This is inline comment 3.

    // Inline comment at the end of struct.
};

// This is inline comment 4.
// This is inline comment 5.

/* Comment, comment. */

// This is inline comment 6.

/* Comment, comment. */
C",
q"D
extern (C):

extern __gshared int a; // This is inline comment 1.
extern __gshared int b; // This is inline comment 2.

struct X
{
    int field; // This is inline comment 3.

    // Inline comment at the end of struct.
}

// This is inline comment 4.
// This is inline comment 5.

/* Comment, comment. */

// This is inline comment 6.

/* Comment, comment. */
D");

}

// Do not generate alias for typedef with the same name as structure.
unittest
{
    assertTranslates(q"C
typedef struct Foo Foo;
struct Foo;
struct Foo
{
    struct Bar
    {
        int x;
    } bar;
};
C",
q"D
extern (C):

struct Foo
{
    struct Bar
    {
        int x;
    }

    Bar bar;
}

D");
}

// Long function declarations should be broken to multiple lines.
unittest
{
    assertTranslates(q"C
void very_long_function_declaration(double way_too_long_argument, double another_long_argument);
C",
q"D
extern (C):

void very_long_function_declaration (
    double way_too_long_argument,
    double another_long_argument);
D");

}
