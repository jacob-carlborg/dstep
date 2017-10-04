/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: September 16, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import std.stdio;
import Common;
import dstep.translator.Translator;

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

// Long function pointer declarations should be broken to multiple lines.
unittest
{
    assertTranslates(q"C
typedef void (*very_long_function_pointer)(int foofoofoo,
                                   int barbarbarbar,
                                   unsigned bazbazbaz,
                                   unsigned quxquxqux0,
                                   unsigned quxquxqux1);
C",
q"D
extern (C):

alias very_long_function_pointer = void function (
    int foofoofoo,
    int barbarbarbar,
    uint bazbazbaz,
    uint quxquxqux0,
    uint quxquxqux1);
D");

}

// Long nested function pointer declarations should be broken to multiple lines.
unittest
{
    assertTranslates(q"C
typedef struct {
    void (*very_long_function_pointer)(int foofoofoo,
                                       int barbarbarbar,
                                       unsigned bazbazbaz,
                                       unsigned quxquxqux0,
                                       unsigned quxquxqux1);
} foo_t;
C",
    q"D
extern (C):

struct foo_t
{
    void function (
        int foofoofoo,
        int barbarbarbar,
        uint bazbazbaz,
        uint quxquxqux0,
        uint quxquxqux1) very_long_function_pointer;
}
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
    auto source = q"C
void very_long_function_declaration(double way_too_long_argument,
                           double another_long_argument);

void (*very_long_function_pointer)(double way_too_long_argument,
        double another_long_argument);
C";

    Options options;
    options.singleLineFunctionSignatures = true;

    assertTranslates(source, q"D
extern (C):

void very_long_function_declaration (double way_too_long_argument, double another_long_argument);

extern __gshared void function (double way_too_long_argument, double another_long_argument) very_long_function_pointer;
D", options);

    options.singleLineFunctionSignatures = false;

    assertTranslates(source, q"D
extern (C):

void very_long_function_declaration (
    double way_too_long_argument,
    double another_long_argument);

extern __gshared void function (
    double way_too_long_argument,
    double another_long_argument) very_long_function_pointer;
D", options);

}

// Test not putting a space after a function name.
unittest
{
    Options options;
    options.spaceAfterFunctionName = false;

    assertTranslates(q"C
void very_long_function_declaration(double way_too_long_argument, double another_long_argument);
C",
q"D
extern (C):

void very_long_function_declaration(double way_too_long_argument, double another_long_argument);
D", options);

}
