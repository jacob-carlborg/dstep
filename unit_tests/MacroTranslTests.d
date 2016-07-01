/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 02, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import core.exception;

import Common;
import Assert;

import clang.c.Index;

import dstep.translator.Context;
import dstep.translator.MacroDefinition;
import dstep.translator.Options;
import dstep.translator.Output;

private alias assertTMD = assertTranslatesMacroDefinition;
private alias assertTME = assertTranslatesMacroExpression;
private alias assertDPME = assertDoesntParseMacroExpression;

// Translate basic macro definitions.
unittest
{
    assertTMD(q"C
#define FOO
C", q"D
D");

    assertTMD(q"C
#define FOO 1
C", q"D
enum FOO = 1;
D");

    assertTMD(q"C
#define FOO "bar"
C", q"D
enum FOO = "bar";
D");

    assertTMD(q"C
#define FOO() 0
C", q"D
extern (D) int FOO()
{
    return 0;
}
D");

    assertTMD(q"C
#define FOO(a, b) a + b
C", q"D
extern (D) auto FOO(T0, T1)(auto ref T0 a, auto ref T1 b)
{
    return a + b;
}
D");

    assertTMD(q"C
#define FOO() 0 + 1
C", q"D
extern (D) int FOO()
{
    return 0 + 1;
}
D");

    assertTMD(q"C
#define FOO(a, b, c) (\
    ((a) * 100) \
  + ((b) * 10) \
  + c)
C", q"D
extern (D) auto FOO(T0, T1, T2)(auto ref T0 a, auto ref T1 b, auto ref T2 c)
{
    return (a * 100) + (b * 10) + c;
}
D");

    assertTMD(q"C
#define STRINGIZE(major, minor) #major"."#minor
C", q"D
extern (D) string STRINGIZE(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    import std.conv : to;

    return to!string(major) ~ "." ~ to!string(minor);
}
D");

    assertTMD(q"C
#define VERSION ENCODE( \
    MAJOR, \
    MINOR)
C", q"D
enum VERSION = ENCODE(MAJOR, MINOR);
D");

}

// Translate simple expressions.
unittest
{
    assertTMD(q"C
#define FOO(a) a + 1
C", q"D
extern (D) auto FOO(T)(auto ref T a)
{
    return a + 1;
}
D");

    assertTMD(q"C
#define FOO(a) a * 1 / 2 % 3
C", q"D
extern (D) auto FOO(T)(auto ref T a)
{
    return a * 1 / 2 % 3;
}
D");

    assertTMD(q"C
#define FOO(a) a -1 + 2
C", q"D
extern (D) auto FOO(T)(auto ref T a)
{
    return a - 1 + 2;
}
D");

    assertTMD(q"C
#define FOO(a) a << 1 >> 2
C", q"D
extern (D) auto FOO(T)(auto ref T a)
{
    return a << 1 >> 2;
}
D");

    assertTMD(q"C
#define FOO(a) a < 1 && a < 2 && 1 <= 2 && 2 >= 3 || 1 == 1 || a != a
C", q"D
extern (D) auto FOO(T)(auto ref T a)
{
    return a < 1 && a < 2 && 1 <= 2 && 2 >= 3 || 1 == 1 || a != a;
}
D");

    assertTMD(q"C
#define FOO(a) ((a) == 1 ? 0 : 1 ? 2 : 3)
C", q"D
extern (D) int FOO(T)(auto ref T a)
{
    return a == 1 ? 0 : 1 ? 2 : 3;
}
D");

}

// Translate cast operator.
unittest
{
    assertTMD(q"C
#define FOO(a) (float)(a)
C", q"D
extern (D) auto FOO(T)(auto ref T a)
{
    return cast(float) a;
}
D");

}

// Translate unary operators.
unittest
{
    assertTMD(q"C
#define FOO(a, b, c, d, e, f) ++a + --b + &c + *d + +e - (-f)
C", q"D
extern (D) auto FOO(T0, T1, T2, T3, T4, T5)(auto ref T0 a, auto ref T1 b, auto ref T2 c, auto ref T3 d, auto ref T4 e, auto ref T5 f)
{
    return ++a + --b + &c + *d + +e - (-f);
}
D");

    assertTMD(q"C
#define FOO(a) sizeof a
C", q"D
extern (D) size_t FOO(T)(auto ref T a)
{
    return a.sizeof;
}
D");

    assertTMD(q"C
#define FOO(a, b) sizeof (a + b)
C", q"D
extern (D) size_t FOO(T0, T1)(auto ref T0 a, auto ref T1 b)
{
    return (a + b).sizeof;
}
D");

}

// Translate postfix expressions.
unittest
{
    assertTMD(q"C
#define STRINGIZE_(major, minor) FOO()
C", q"D
extern (D) auto STRINGIZE_(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    return FOO();
}
D");

}

// Translate function as alias if the only expression is a function call.
unittest
{
    assertTranslates(q"C
#define STRINGIZE_(major, minor)   \
    #major"."#minor
#define STRINGIZE(major, minor)    \
    STRINGIZE_(major, minor)
C", q"D
extern (C):

extern (D) string STRINGIZE_(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    import std.conv : to;

    return to!string(major) ~ "." ~ to!string(minor);
}

alias STRINGIZE = STRINGIZE_;
D");

    assertTranslates(q"C
#define STRINGIZE_(major, minor)   \
    #major"."#minor
#define STRINGIZE(major, minor)    \
    STRINGIZE_(major)
C", q"D
extern (C):

extern (D) string STRINGIZE_(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    import std.conv : to;

    return to!string(major) ~ "." ~ to!string(minor);
}

extern (D) auto STRINGIZE(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    return STRINGIZE_(major);
}
D");

}

// Translate member access operators.
unittest
{
    assertTranslates(q"C
#define foo(x) x.a
#define boo(x) x->a
C", q"D
extern (C):

extern (D) auto foo(T)(auto ref T x)
{
    return x.a;
}

extern (D) auto boo(T)(auto ref T x)
{
    return x.a;
}
D");

}

// Translate index operator.
unittest
{
    assertTranslates(q"C
#define foo(x) x[32]
C", q"D
extern (C):

extern (D) auto foo(T)(auto ref T x)
{
    return x[32];
}
D");

}

// Translate increment decrement operators.
unittest
{
    assertTranslates(q"C
#define foo(x) ++x
#define bar(x) --x
#define baz(x) x++
#define qux(x) x--
C", q"D
extern (C):

extern (D) auto foo(T)(auto ref T x)
{
    return ++x;
}

extern (D) auto bar(T)(auto ref T x)
{
    return --x;
}

extern (D) auto baz(T)(auto ref T x)
{
    return x++;
}

extern (D) auto qux(T)(auto ref T x)
{
    return x--;
}
D");

}

// Disambiguate between constant and function versions of macros.
unittest
{
    assertTranslates(q"C
#define FOO 0
#define BAR(FOO) FOO
#define BAZ (FOO)
C", q"D
extern (C):

enum FOO = 0;

extern (D) auto BAR(T)(auto ref T FOO)
{
    return FOO;
}

enum BAZ = FOO;
D");

}

// Some example from libpng.
unittest
{
    assertTranslates(q"C
#define COLOR_DIST(c1, c2) (abs((int)((c1).red) - (int)((c2).red)) + \
   abs((int)((c1).green) - (int)((c2).green)) + \
   abs((int)((c1).blue) - (int)((c2).blue)))
C", q"D
extern (C):

extern (D) auto COLOR_DIST(T0, T1)(auto ref T0 c1, auto ref T1 c2)
{
    return abs(cast(int) c1.red - cast(int) c2.red) + abs(cast(int) c1.green - cast(int) c2.green) + abs(cast(int) c1.blue - cast(int) c2.blue);
}
D");

    assertTranslates(q"C
typedef unsigned int uint_32;

#define ROWBYTES(pixel_bits, width) \
    ((pixel_bits) >= 8 ? \
    ((width) * (((uint_32)(pixel_bits)) >> 3)) : \
    (( ((width) * ((uint_32)(pixel_bits))) + 7) >> 3) )
C", q"D
extern (C):

alias uint uint_32;

extern (D) auto ROWBYTES(T0, T1)(auto ref T0 pixel_bits, auto ref T1 width)
{
    return pixel_bits >= 8 ? (width * ((cast(uint_32) pixel_bits) >> 3)) : (((width * (cast(uint_32) pixel_bits)) + 7) >> 3);
}
D");

    assertTranslates(q"C
#define OUT_OF_RANGE(value, ideal, delta) \
        ( (value) < (ideal)-(delta) || (value) > (ideal)+(delta) )
C", q"D
extern (C):

extern (D) auto OUT_OF_RANGE(T0, T1, T2)(auto ref T0 value, auto ref T1 ideal, auto ref T2 delta)
{
    return value < ideal - delta || value > ideal + delta;
}
D");

    assertTranslates(q"C
typedef unsigned uint_32;
typedef unsigned long long foo_t;

#define UINT_31_MAX ((uint_32)0x7fffffffL)
#define UINT_32_MAX ((uint_32)(-1))
#define FOO_MAX ((foo_t)(-1))
#define MAX_UINT UINT_31_MAX
C", q"D
extern (C):

alias uint uint_32;
alias ulong foo_t;

enum UINT_31_MAX = cast(uint_32) 0x7fffffffL;
enum UINT_32_MAX = cast(uint_32) -1;
enum FOO_MAX = cast(foo_t) -1;
enum MAX_UINT = UINT_31_MAX;
D");

}

// Translate const qualifier,
unittest
{
    assertTME("#define FOO(a) (const int)(a)", "cast(const int) a");
    assertTME("#define FOO(a) (int const)(a)", "cast(const int) a");

    assertTME("#define FOO(a) (const int*)(a)", "cast(const(int)*) a");
    assertTME("#define FOO(a) (int const*)(a)", "cast(const(int)*) a");

    assertTME("#define FOO(a) (int const* const*)(a)", "cast(const(int*)*) a");
    assertTME("#define FOO(a) (int* const*)(a)", "cast(int**) a");
}

// Translate casting to complex types.
unittest
{
        assertTranslates(q"C
typedef int uint_32;

#define Foo() (uint_32)(0)
C", q"D
extern (C):

alias int uint_32;

extern (D) auto Foo()
{
    return cast(uint_32) 0;
}
D");

    assertTranslates(q"C
enum Bar { BAR = 0 };

#define Foo() (Bar)(0)
C", q"D
extern (C):

enum Bar
{
    BAR = 0
}

extern (D) auto Foo()
{
    return cast(Bar) 0;
}
D");

    assertTranslates(q"C
struct Bar { };

#define Foo() (struct Bar)(0)
C", q"D
extern (C):

struct Bar
{
}

extern (D) auto Foo()
{
    return cast(Bar) 0;
}
D");

    assertTranslates(q"C
union Bar { };

#define Foo() (union Bar)(0)
C", q"D
extern (C):

union Bar
{
}

extern (D) auto Foo()
{
    return cast(Bar) 0;
}
D");

    assertTranslates(q"C
union Bar { };

#define Foo() (union Bar*)(0)
C", q"D
extern (C):

union Bar
{
}

extern (D) auto Foo()
{
    return cast(Bar*) 0;
}
D");

    assertTranslates(q"C
union Bar { };

#define Foo() (const union Bar*)(0)
C", q"D
extern (C):

union Bar
{
}

extern (D) auto Foo()
{
    return cast(const(Bar)*) 0;
}
D");

}

// Translate type dependent macros.
unittest
{
    assertTranslates(q"C

typedef int uint_32;

#define ROWBYTES(pixel_bits) (uint_32)(pixel_bits)
C", q"D
extern (C):

alias int uint_32;

extern (D) auto ROWBYTES(T)(auto ref T pixel_bits)
{
    return cast(uint_32) pixel_bits;
}
D");

}

// Translate sizeof type.
unittest
{
    assertTranslates(q"C
#define FOO sizeof(int)
#define BAR sizeof(unsigned int)
#define BAZ sizeof(unsigned long long)
C",
q"D
extern (C):

enum FOO = int.sizeof;
enum BAR = uint.sizeof;
enum BAZ = ulong.sizeof;
D");

    assertTranslates(q"C
struct Bar
{
};

#define FOO sizeof(Bar)
C",
q"D
extern (C):

struct Bar
{
}

enum FOO = Bar.sizeof;
D");

}
