/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jul 27, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

import clang.Util;

import dstep.translator.Options;

// Fix 58: Symbol selection.

void assertSkipSymbols(
    string[] symbols,
    string source,
    string expected,
    string file = __FILE__,
    size_t line = __LINE__)
{
    Options options;

    options.skipSymbols = setFromList(symbols);

    assertTranslates(source, expected, options, false, file, line);
}

void assertSkipdefSymbols(
    string[] symbols,
    string source,
    string expected,
    string file = __FILE__,
    size_t line = __LINE__)
{
    Options options;

    options.skipDefinitions = setFromList(symbols);

    assertTranslates(source, expected, options, false, file, line);
}

unittest
{
    // Skip variable.
    assertSkipSymbols(
        ["foo"], q"C
int foo;
int bar;
C", q"D
extern (C):

extern __gshared int bar;
D");

    // Skip function.
    assertSkipSymbols(
        ["foo"], q"C
int foo(int a, int b, int c);
int bar(int a, int b, int c);
C", q"D
extern (C):

int bar (int a, int b, int c);
D");

    // Skip struct.
    assertSkipSymbols(
        ["Foo"], q"C
struct Foo {
};

struct Bar {
};
C", q"D
extern (C):

struct Bar
{
}
D");

    // Skip union.
    assertSkipSymbols(
        ["Foo"], q"C
union Foo {
};

union Bar {
};
C", q"D
extern (C):

union Bar
{
}
D");

    // Skip typedef.
    assertSkipSymbols(
        ["Baz"], q"C
struct Foo { };
typedef struct Foo Bar;
typedef struct Foo Baz;
C", q"D
extern (C):

struct Foo
{
}

alias Bar = Foo;
D");

    // Skip macro-definition.
    assertSkipSymbols(
        ["FOO", "BAZ"], q"C
#define FOO 42
#define BAR 31415
#define BAZ(x) x * 2
#define QUX(x) x == 42 ? 0 : 1
C", q"D
extern (C):

enum BAR = 31415;

extern (D) int QUX(T)(auto ref T x)
{
    return x == 42 ? 0 : 1;
}
D");

}

unittest
{
    assertSkipdefSymbols(
        ["Foo"], q"C
struct Foo {
    int foo;
    int bar;
};

struct Bar {
    int baz;
    int qux;
};
C", q"D
extern (C):

struct Foo;

struct Bar
{
    int baz;
    int qux;
}
D");

    assertSkipdefSymbols(
        ["Foo"], q"C
typedef struct Foo {
    int foo;
    int bar;
} Foo;

typedef struct Bar {
    int baz;
    int qux;
} Bar;
C", q"D
extern (C):

struct Foo;

struct Bar
{
    int baz;
    int qux;
}
D");

    assertSkipdefSymbols(
        ["Foo"], q"C
typedef struct {
    int foo;
    int bar;
} Foo;

typedef struct {
    int baz;
    int qux;
} Bar;
C", q"D
extern (C):

struct Foo;

struct Bar
{
    int baz;
    int qux;
}
D");

    assertSkipdefSymbols(
        ["Foo"], q"C
typedef struct Foo {
    int foo;
    int bar;
} Bar;
C", q"D
extern (C):

struct Foo;
alias Bar = Foo;
D");

}

unittest
{
    assertSkipSymbols(
        ["Foo"], q"C
typedef struct Foo {
    int foo;
    int bar;
} Bar;
C", q"D
extern (C):

D");

}
