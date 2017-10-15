/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: October 13, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import core.exception;

import std.container.dlist;
import std.variant;

import Common;
import Assert;

import dstep.translator.MacroDefinition;

unittest
{
    assertTranslates(q"C
#define FOO(x) BAR(int)
C", q"D
extern (C):

extern (D) auto FOO(T)(auto ref T x)
{
    return BAR(int);
}
D");
}

unittest
{
    assertTranslates(q"C
#define BAR(x) 0
#define FOO(x) BAR(int)
C", q"D
extern (C):

extern (D) int BAR(x)()
{
    return 0;
}

extern (D) auto FOO(T)(auto ref T x)
{
    return BAR!int();
}
D");
}

unittest
{
    assertTranslates(q"C
#define BAR(x, y, z) x * y * sizeof(z)

#define BAZ BAR(0, 1, float)
C", q"D
extern (C):

extern (D) auto BAR(z, T0, T1)(auto ref T0 x, auto ref T1 y)
{
    return x * y * z.sizeof;
}

enum BAZ = BAR!float(0, 1);
D");

}

unittest
{
    assertTranslates(q"C
typedef struct { } foo_t;

#define BAR(x, y, z) x * y * sizeof(z)

#define BAZ BAR(0, 1, foo_t)
C", q"D
extern (C):

struct foo_t
{
}

extern (D) auto BAR(z, T0, T1)(auto ref T0 x, auto ref T1 y)
{
    return x * y * z.sizeof;
}

enum BAZ = BAR!foo_t(0, 1);
D");

}

unittest
{
    assertTranslates(q"C
typedef unsigned int __u32;

#define BAR(x) sizeof(x)

#define BAZ BAR(__u32)
C", q"D
extern (C):

extern (D) size_t BAR(x)()
{
    return x.sizeof;
}

enum BAZ = BAR!uint();
D");

}

unittest
{
    assertTranslates(q"C
#define FOO() 0

#define BAR(x) BAZ(0, 1, x)

#define BAZ(x, y, z) sizeof(z) * x * y

#define QUX(x) BAR(float)
C", q"D
extern (C):

extern (D) int FOO()
{
    return 0;
}

extern (D) auto BAR(x)()
{
    return BAZ!x(0, 1);
}

extern (D) auto BAZ(z, T0, T1)(auto ref T0 x, auto ref T1 y)
{
    return z.sizeof * x * y;
}

extern (D) auto QUX(T)(auto ref T x)
{
    return BAR!float();
}
D");

}

unittest
{
    assertTranslates(q"C
#define FOO(type) sizeof(type)

#define BAR FOO(unsigned int)
#define BAZ FOO(unsigned short)
#define QUX FOO(long)
C", q"D
import core.stdc.config;

extern (C):

extern (D) size_t FOO(type)()
{
    return type.sizeof;
}

enum BAR = FOO!uint();
enum BAZ = FOO!ushort();
enum QUX = FOO!c_long();
D");
}

unittest
{
    assertTranslates(q"C
#define FOO(a, b, c, d) 0

#define BAR(t) sizeof(t)

#define BAZ(x2,x3) FOO(x0,(x2),(x3),0)
#define QUX(x2,x3,type) FOO(x4,(x2),(x3),(BAR(type)))

#define ENUM0 QUX('a', 0, char)
#define ENUM1 QUX('b', 1, short)
#define ENUM2 QUX('c', 2, int)
C", q"D
extern (C):

extern (D) int FOO(T0, T1, T2, T3)(auto ref T0 a, auto ref T1 b, auto ref T2 c, auto ref T3 d)
{
    return 0;
}

extern (D) size_t BAR(t)()
{
    return t.sizeof;
}

extern (D) auto BAZ(T0, T1)(auto ref T0 x2, auto ref T1 x3)
{
    return FOO(x0, x2, x3, 0);
}

extern (D) auto QUX(type, T0, T1)(auto ref T0 x2, auto ref T1 x3)
{
    return FOO(x4, x2, x3, BAR!type());
}

enum ENUM0 = QUX!char('a', 0);
enum ENUM1 = QUX!short('b', 1);
enum ENUM2 = QUX!int('c', 2);
D");

}
