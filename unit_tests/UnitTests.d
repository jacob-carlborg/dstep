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
void very_long_function_declaration(double way_too_long_argument,
                           double another_long_argument);
C",
q"D
extern (C):

void very_long_function_declaration (
    double way_too_long_argument,
    double another_long_argument);
D");

}

// Long function declarations shouldn't be broken, if they aren't in original.
unittest
{
    assertTranslates(q"C
void very_long_function_declaration(double way_too_long_argument, double another_long_argument);
C",
q"D
extern (C):

void very_long_function_declaration (double way_too_long_argument, double another_long_argument);
D");

}

// Long function declarations shouldn't be broken, if disabled in options.
unittest
{
    Options options;
    options.singleLineFunctionHeaders = true;

    assertTranslates(q"C
void very_long_function_declaration(double way_too_long_argument,
                           double another_long_argument);
C",
q"D
extern (C):

void very_long_function_declaration (double way_too_long_argument, double another_long_argument);
D", options);

}

// Test not putting a space after a function name.
unittest
{
    Options options;
    options.noSpaceAfterFunctionName = true;

    assertTranslates(q"C
void very_long_function_declaration(double way_too_long_argument, double another_long_argument);
C",
q"D
extern (C):

void very_long_function_declaration(double way_too_long_argument, double another_long_argument);
D", options);

}

// Test translation of nested anonymous structures that have associated fields.
unittest
{
    assertTranslates(q"C
struct C
{
    struct
    {
        int x;
        int y;

        struct
        {
            int z;
            int w;
        } nested;
    } point;
};
C",
q"D
extern (C):

struct C
{
    struct _Anonymous_0
    {
        int x;
        int y;

        struct _Anonymous_1
        {
            int z;
            int w;
        }

        _Anonymous_1 nested;
    }

    _Anonymous_0 point;
}

D");

}

// Test comments that contains std.format format specifiers.
unittest
{
    assertTranslates(q"C
/* This is comment containing unescaped %. */
C",
q"D
/* This is comment containing unescaped %. */
D");
}

// Test translation of interleaved enum-based array size consts and macro based array size consts.
unittest
{
    assertTranslates(
q"C

struct qux {
    char scale;
};

#define FOO 4
#define BAZ 8

struct stats_t {
    enum
    {
        BAR = 55,
    };

    struct qux stat[FOO][BAR][FOO][BAZ];
};

C",
q"D
extern (C):

struct qux
{
    char scale;
}

enum FOO = 4;
enum BAZ = 8;

struct stats_t
{
    enum _Anonymous_0
    {
        BAR = 55
    }

    qux[BAZ][FOO][BAR][FOO] stat;
}

alias BAR = stats_t._Anonymous_0.BAR;

D");

}

// Test specifying package name.
unittest
{
    Options options;
    options.outputFile = "qux/Baz.d";
    options.packageName = "foo.bar";

    assertTranslates(q"C
int a;
C", q"D
module foo.bar.Baz;

extern (C):

extern __gshared int a;
D", options);

}

// Translate size types as size types.
unittest
{
   assertTranslates(
q"C
#include <stddef.h>

size_t foo;
ptrdiff_t bar;
C",
q"D
extern (C):

extern __gshared size_t foo;
extern __gshared ptrdiff_t bar;
D");

}

// Reduce typedefs when underlying type is alias of primitive type.
unittest
{
    Options options;
    options.reduceAliases = true;

    assertTranslates(
q"C
#include <stdint.h>

uint8_t foo;
uint32_t bar;
C", q"D
extern (C):

extern __gshared ubyte foo;
extern __gshared uint bar;
D", options);

}

// Do not reduce aliases of unknown types.
unittest
{
   Options options;
   options.reduceAliases = true;

   assertTranslates(
q"C
typedef unsigned int Bar;
Bar foo;
C",
q"D
extern (C):

alias uint Bar;
extern __gshared Bar foo;
D", options);

}

// Disable alias reduction.
unittest
{
    Options options;
    options.reduceAliases = false;

    assertTranslates(
q"C
#include <stdint.h>

uint8_t foo;
uint32_t bar;
C",
q"D
import core.stdc.stdint;

extern (C):

extern __gshared uint8_t foo;
extern __gshared uint32_t bar;

D", options);

    options.reduceAliases = true;

    assertTranslates(
q"C
#include <stdint.h>

uint8_t foo;
uint32_t bar;
C", q"D
extern (C):

extern __gshared ubyte foo;
extern __gshared uint bar;
D", options);

}

// Translate array with immediate struct declaration.
unittest
{
    assertTranslates(q"C
struct Foo {
  struct Bar {

  } bar[64];
};
C",
q"D
extern (C):

struct Foo
{
    struct Bar
    {
    }

    Bar[64] bar;
}
D");

}

// Test portable wchar_t.
unittest
{
    assertTranslates(q"C
#include <wchar.h>

wchar_t x;
C",
q"D
import core.stdc.stddef;

extern (C):

extern __gshared wchar_t x;
D");

    Options options;
    options.portableWCharT = false;

    assertTranslates(q"C
#include <wchar.h>

wchar_t x;
C",
q"D
extern (C):

extern __gshared dchar x;
D", options);

}

// Test translation of the function with no argument list.
unittest
{
    assertTranslates(q"C
void foo();
C",
q"D
extern (C):

void foo ();
D");

    Options options;
    options.zeroParamIsVararg = true;

    assertTranslates(q"C
void foo();
C",
q"D
extern (C):

void foo (...);
D", options);

}

// Test specifying package name.
unittest
{
    Options options;
    options.outputFile = "qux/Baz.d";
    options.packageName = "foo.bar";

    assertTranslates(q"C
int a;
C", q"D
module foo.bar.Baz;

extern (C):

extern __gshared int a;
D", options);

}

// Test translation of function pointers.
unittest
{
    assertTranslates(q"C
typedef void *ClientData;

typedef struct { } EntityInfo;

void (*fun)(ClientData client_data, const EntityInfo*, unsigned last);
C", q"D
extern (C):

alias void* ClientData;

struct EntityInfo
{
}

extern __gshared void function (ClientData client_data, const(EntityInfo)*, uint last) fun;
D");

    assertTranslates(q"C
typedef void* ClientData;

typedef struct { } Cursor;

enum VisitorResult {
    Break,
    Continue
};

typedef enum VisitorResult (*FunPtr)(Cursor C, ClientData client_data);
C", q"D
extern (C):

alias void* ClientData;

struct Cursor
{
}

enum VisitorResult
{
    Break = 0,
    Continue = 1
}

alias VisitorResult function (Cursor C, ClientData client_data) FunPtr;
D");

    assertTranslates(q"C
typedef void* ClientData;

typedef void (*FunPtr)(int c, ClientData client_data);
C", q"D
extern (C):

alias void* ClientData;

alias void function (int c, ClientData client_data) FunPtr;
D");

}

// Test translation of array arguments.
unittest
{
    assertTranslates(q"C
int foo (int data[]);
int bar (const int data[]);
int baz (const int data[32]);
int qux (const int data[32][64]);
C",
q"D
extern (C):

int foo (int* data);
int bar (const(int)* data);
int baz (ref const(int)[32] data);
int qux (ref const(int)[64][32] data);
D");

    // A case with the pointer as an element type.
    assertTranslates(q"C
int foo (const void *ptr_data[2]);
C", q"D
extern (C):

int foo (ref const(void)*[2] ptr_data);
D");

}
