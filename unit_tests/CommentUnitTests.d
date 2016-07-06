/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: May 21, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import std.stdio;
import Common;
import dstep.translator.Translator;

// Empty file translates to empty file.
unittest
{
    assertTranslates(
q"C
C",
q"D
D", true);
}

// Test disabled comments.
unittest
{
    Options options;
    options.language = Language.c;
    options.enableComments = false;

    assertTranslates(
q"C
    /* Disabled comments. */
C",
q"D
D", options, false);
}

// Test single comment.
unittest
{
    assertTranslates(
q"C
/* Enabled comments. */
C",
q"D
/* Enabled comments. */
D", true);
}

// Test header comment handling.
unittest
{
	assertTranslates(
q"C
/* Header comment. */

/* Comment before variable. */
int variable;
C",
q"D
/* Header comment. */

extern (C):

/* Comment before variable. */
extern __gshared int variable;
D", true);

    assertTranslates(
q"C

/* Header comment. */

/* Comment before variable. */
int variable;
C",
q"D
extern (C):

/* Header comment. */

/* Comment before variable. */
extern __gshared int variable;
D", true);

	assertTranslates(
q"C
/* Header
   comment.
*/

/* Comment before variable. */
int variable;
C",
q"D
/* Header
   comment.
*/

extern (C):

/* Comment before variable. */
extern __gshared int variable;
D", true);

}

// Test translation of comments inside an enum.
unittest
{
    assertTranslates(
q"C

enum Foo {
    foo, /* Inline comment. */
};
C",
q"D
extern (C):

enum Foo
{
    foo = 0 /* Inline comment. */
}
D");

    assertTranslates(
q"C

/* This is an enumeration. */

enum Foo {
    /* An enum constant. */
    FOO,

    /* Another one. */
    BAR = 0,

    /* And one more. */

    BAZ,
};
C",
q"D
extern (C):

/* This is an enumeration. */

enum Foo
{
    /* An enum constant. */
    FOO = 0,

    /* Another one. */
    BAR = 0,

    /* And one more. */

    BAZ = 1
}
D");

}

// Test translation of comments inside a struct.
unittest
{
    assertTranslates(
q"C

/* This is a structure. */

struct Foo {
    /* A comment inside a struct. */
};
C",
q"D
extern (C):

/* This is a structure. */

struct Foo
{
    /* A comment inside a struct. */
}
D");

    assertTranslates(
q"C

/* This is a structure. */

struct Foo {
    /* A comment inside a struct. */
    int Foo;

    /* BAR */

    int Bar; /* INLINE */
};
C",
q"D
extern (C):

/* This is a structure. */

struct Foo
{
    /* A comment inside a struct. */
    int Foo;

    /* BAR */

    int Bar; /* INLINE */
}
D");

}

// Test indented comments.
unittest
{
    assertTranslates(
q"C
struct Foo {
    /* FOO
     * BAR
     * BAZ */
    int Foo;
};
C",
q"D
extern (C):

struct Foo
{
    /* FOO
     * BAR
     * BAZ */
    int Foo;
}
D");

}
