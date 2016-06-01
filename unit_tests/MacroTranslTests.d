/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 02, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

import dstep.translator.Context;
import dstep.translator.MacroDefinition;
import dstep.translator.Output;

void assertTranslatesMacroDefinition(
    string expected,
    string source,
    string file = __FILE__,
    size_t line = __LINE__)
{
    auto translUnit = makeTranslationUnit(source);

    Output output = new Output;
    Context context = new Context(translUnit);

    context.macroLinkage = "";

    auto children = translUnit.cursor.children(true);

    assert(children.length == 1);

    translMacroDefinition(output, context, children[0]);

    assertEq(expected, output.data, false, file, line);
}

private alias assertTMD = assertTranslatesMacroDefinition;

// Translate basic macro definitions.
unittest
{
    assertTMD(q"D
D", q"C
#define FOO
C");

    assertTMD(q"D
enum FOO = 1;
D", q"C
#define FOO 1
C");

    assertTMD(q"D
enum FOO = "bar";
D", q"C
#define FOO "bar"
C");

    assertTMD(q"D
int FOO()
{
    return 0;
}
D", q"C
#define FOO() 0
C");

    assertTMD(q"D
int FOO()
{
    return 0;
}
D", q"C
#define FOO() 0
C");

    assertTMD(q"D
T FOO(T)(in T a, in T b)
{
    return a + b;
}
D", q"C
#define FOO(a, b) a + b
C");

    assertTMD(q"D
int FOO()
{
    return 0 + 1;
}
D", q"C
#define FOO() 0 + 1
C");

    assertTMD(q"D
int FOO(int a)
{
    return a + 1;
}
D", q"C
#define FOO(a) a + 1
C");

    assertTMD(q"D
int FOO(int a, int b, int c)
{
    return (a * 100) + (b * 10) + c;
}
D", q"C
#define FOO(a, b, c) (\
    ((a) * 100) \
  + ((b) * 10) \
  + c)
C");

    assertTMD(q"D
string STRINGIZE(T)(in T major, in T minor)
{
    import std.conv;

    return to!string(major) ~ "." ~ to!string(minor);
}
D", q"C
#define STRINGIZE(major, minor) #major"."#minor
C");

    assertTMD(q"D
enum VERSION = ENCODE(MAJOR, MINOR);
D", q"C
#define VERSION ENCODE( \
    MAJOR, \
    MINOR)
C");

}

// Translate simple expressions.
unittest
{
    assertTMD(q"D
int FOO(int a)
{
    return a + 1;
}
D", q"C
#define FOO(a) a + 1
C");

    assertTMD(q"D
int FOO(int a)
{
    return a * 1 / 2 % 3;
}
D", q"C
#define FOO(a) a * 1 / 2 % 3
C");

    assertTMD(q"D
int FOO(int a)
{
    return a - 1 + 2;
}
D", q"C
#define FOO(a) a -1 + 2
C");

    assertTMD(q"D
int FOO(int a)
{
    return a << 1 >> 2;
}
D", q"C
#define FOO(a) a << 1 >> 2
C");

    assertTMD(q"D
int FOO(int a)
{
    return a < 1 && a < 2 && 1 <= 2 && 2 >= 3 || 1 == 1 || a != a;
}
D", q"C
#define FOO(a) a < 1 && a < 2 && 1 <= 2 && 2 >= 3 || 1 == 1 || a != a
C");

    assertTMD(q"D
int FOO(int a)
{
    return a == 1 ? 0 : 1 ? 2 : 3;
}
D", q"C
#define FOO(a) ((a) == 1 ? 0 : 1 ? 2 : 3)
C");

}

// Translate cast operator (FIXME: type inference)
unittest
{
    assertTMD(q"D
T FOO(T)(in T a)
{
    return cast (float) a;
}
D", q"C
#define FOO(a) (float)(a)
C");

}

// Translate unary operators.
unittest
{
    assertTMD(q"D
T FOO(T)(in T a, in T b, in T c, in T d, in T e, in T f)
{
    return ++a + --b + &c + *d + +e - (-f);
}
D", q"C
#define FOO(a, b, c, d, e, f) ++a + --b + &c + *d + +e - (-f)
C");

    assertTMD(q"D
T FOO(T)(in T a)
{
    return sizeof(a);
}
D", q"C
#define FOO(a) sizeof a
C");

}

// Translate postfix expressions.
unittest
{
    assertTMD(q"D
T STRINGIZE_(T)(in T major, in T minor)
{
    return FOO();
}
D", q"C
#define STRINGIZE_(major, minor) FOO()
C");

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

extern (D) string STRINGIZE_(T)(in T major, in T minor)
{
    import std.conv;

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

extern (D) string STRINGIZE_(T)(in T major, in T minor)
{
    import std.conv;

    return to!string(major) ~ "." ~ to!string(minor);
}

extern (D) T STRINGIZE(T)(in T major, in T minor)
{
    return STRINGIZE_(major);
}
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

extern (D) T COLOR_DIST(T)(in T c1, in T c2)
{
    return abs(cast (int) c1.red - cast (int) c2.red) + abs(cast (int) c1.green - cast (int) c2.green) + abs(cast (int) c1.blue - cast (int) c2.blue);
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

extern (D) T foo(T)(in T x)
{
    return x.a;
}

extern (D) T boo(T)(in T x)
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

extern (D) T foo(T)(in T x)
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

extern (D) T foo(T)(in T x)
{
    return ++x;
}

extern (D) T bar(T)(in T x)
{
    return --x;
}

extern (D) T baz(T)(in T x)
{
    return x++;
}

extern (D) T qux(T)(in T x)
{
    return x--;
}
D");

}
