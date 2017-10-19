/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: October 19, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import std.stdio;
import Common;
import dstep.translator.Translator;

unittest
{
    assertTranslates(q"C
typedef enum
{
    a = 1,
    b = 2,
} Foo;

typedef enum
{
    c = b,
    d = c | a
} Bar;
C",
q"D
extern (C):

enum Foo
{
    a = 1,
    b = 2
}

enum Bar
{
    c = Foo.b,
    d = c | Foo.a
}
D");

}

unittest
{
    assertTranslates(q"C
enum Qux
{
    FOO = 1 << 0,
    BAR = 1 << 1,
    BAZ = 1 << 2
};
C",
q"D
extern (C):

enum Qux
{
    FOO = 1 << 0,
    BAR = 1 << 1,
    BAZ = 1 << 2
}
D");

}

unittest
{
    assertTranslates(q"C
enum Foo
{
    a = 0x1,
    b = 0x2,
    c = 1 << 0,
    d = ((1 << 22) - 1)
};
C",
q"D
extern (C):

enum Foo
{
    a = 0x1,
    b = 0x2,
    c = 1 << 0,
    d = (1 << 22) - 1
}
D");

}

unittest
{
    assertTranslates(q"C
enum Foo
{
    a = 1,
    b = 2,
    c = b,
    d = c | a
};
C",
q"D
extern (C):

enum Foo
{
    a = 1,
    b = 2,
    c = b,
    d = c | a
}
D");

}

unittest
{
    assertTranslates(q"C
enum Foo
{
    a = 1,
    b = 2,
};

enum Bar
{
    c = b,
    d = c | a
};
C",
q"D
extern (C):

enum Foo
{
    a = 1,
    b = 2
}

enum Bar
{
    c = Foo.b,
    d = c | Foo.a
}
D");

}

unittest
{
    Options options;
    options.renameEnumMembers = true;

    assertTranslates(q"C
enum Foo
{
    AAA = 1,
    BBB = 2,
};

enum Bar
{
    CCC = BBB,
    DDD = CCC | AAA
};
C",
q"D
extern (C):

enum Foo
{
    aaa = 1,
    bbb = 2
}

enum Bar
{
    ccc = Foo.bbb,
    ddd = ccc | Foo.aaa
}
D", options);

}
