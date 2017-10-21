/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import std.stdio;
import Common;

import dstep.translator.CommentIndex;
import dstep.translator.Output;

// Test empty output.
unittest
{
    Output output = new Output();
    assertEq("", output.data);
    assert(output.empty());
}

// Test separator.
unittest
{
    Output output = new Output();

    output.separator();
    assertEq("", output.data);

    output.separator();
    assertEq("", output.data);

    output.singleLine("int x;");
    assertEq("int x;", output.data);

    output.separator();
    assertEq("int x;", output.data);

    output.singleLine("int x;");
    assertEq("int x;\n\nint x;", output.data);
}

unittest
{
    Output output = new Output();

    output.singleLine("int x;");
    assertEq("int x;", output.data);

    output.separator();
    assertEq("int x;", output.data);

    output.singleLine("int x;");
    assertEq("int x;\n\nint x;", output.data);
}

// Test singleLine.
unittest
{
    Output output = new Output();

    output.separator();
    assertEq("", output.data);

    output.singleLine("int a;");
    output.singleLine("float b;");
    output.separator();
    assertEq("int a;\nfloat b;", output.data);

    output.singleLine("float c;");
    assertEq("int a;\nfloat b;\n\nfloat c;", output.data);
}

// Test subscopeStrong.
unittest
{
    Output output = new Output();

    output.subscopeStrong("struct A") in {
        output.singleLine("int a;");
        output.singleLine("float b;");
        output.singleLine("void func();");
    };

    assertEq(q"D
struct A
{
    int a;
    float b;
    void func();
}
D", output.data("\n"));

    output.subscopeStrong("struct B") in {
        output.singleLine("string s;");
    };

    assertEq(q"D
struct A
{
    int a;
    float b;
    void func();
}

struct B
{
    string s;
}
D", output.data("\n"));

}

// Test multiple nesting.
unittest
{
    Output output = new Output();

    output.subscopeStrong("struct B") in {
        output.singleLine("string s;");
    };

    output.subscopeStrong("struct C") in {
        output.subscopeStrong("void func1()") in {
            output.subscopeStrong("struct B") in {
                output.singleLine("string s;");
            };

            output.singleLine("int a;");
        };

        output.subscopeStrong("void func2()") in {
            output.subscopeStrong("struct B") in {
                output.singleLine("string s;");
            };
        };

        output.singleLine("string s;");
    };

    assertEq(q"D
struct B
{
    string s;
}

struct C
{
    void func1()
    {
        struct B
        {
            string s;
        }

        int a;
    }

    void func2()
    {
        struct B
        {
            string s;
        }
    }

    string s;
}
D", output.data("\n"));

}

// Test multiLine.
unittest
{
    Output output = new Output();

    output.multiLine("case UltimateCase:") in {
        output.singleLine("foo();");
        output.singleLine("bar();");
        output.singleLine("break;");
    };

    assertEq(q"D
case UltimateCase:
    foo();
    bar();
    break;
D", output.data("\n"));

}

// Test empty subscopeStrong
unittest
{
    Output output = new Output();
    output.subscopeStrong("struct A");
    assertEq("struct A\n{\n}", output.data());
}

// Test subscopeStrong after singleLine.
unittest
{
    Output output = new Output();

    output.singleLine("void foo();");
    output.singleLine("void bar();");
    output.subscopeStrong("struct A") in {
        output.singleLine("void bar();");
    };

    assertEq(q"D
void foo();
void bar();

struct A
{
    void bar();
}
D", output.data("\n"));

}

// Test subscopeWeak.
unittest
{
    Output output1 = new Output();

    output1.subscopeWeak("if (true)") in {
        output1.singleLine("int a;");
    };

    assertEq(q"D
if (true)
    int a;
D", output1.data("\n"));

    Output outputN = new Output();

    outputN.subscopeWeak("if (true)") in {
        outputN.singleLine("int a;");
        outputN.singleLine("int b;");
    };

    assertEq(q"D
if (true)
{
    int a;
    int b;
}
D", outputN.data("\n"));

    outputN.subscopeWeak("if (true)") in {
        outputN.singleLine("int a = 1;");
        outputN.singleLine("int b = 2;");
        outputN.singleLine("int c = a + b;");
    };

    assertEq(q"D
if (true)
{
    int a;
    int b;
}

if (true)
{
    int a = 1;
    int b = 2;
    int c = a + b;
}
D", outputN.data("\n"));

}

// Test nested subscopeWeak
unittest
{
    Output output = new Output();

    output.subscopeWeak("if (true)") in {
        output.subscopeWeak("if (false)") in {
            output.subscopeWeak("while (42)") in {
                output.singleLine("foobar();");
            };
        };
    };

assertEq(q"D
if (true)
{
    if (false)
    {
        while (42)
            foobar();
    }
}
D", output.data("\n"));

}

// Test appending one ouput to another.
unittest
{
    Output outputA = new Output();
    Output outputB = new Output();

    outputA.output(outputB);

    assertEq("", outputA.data());
}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();

    outputA.singleLine("int x;");
    outputA.output(outputB);

    assertEq("int x;", outputA.data());
}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();

    outputA.subscopeStrong("struct A");
    outputA.output(outputB);

    assertEq("struct A\n{\n}", outputA.data());
}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();
    Output outputC = new Output();

    outputA.subscopeStrong("struct A");
    outputB.subscopeStrong("struct B");
    outputA.output(outputB);

    assertEq("struct A\n{\n}\n\nstruct B\n{\n}", outputA.data());

    outputC.singleLine("int x;");
    outputB.output(outputC);

    assertEq("struct B\n{\n}\n\nint x;", outputB.data());
}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();
    Output outputC = new Output();

    outputA.singleLine("int x;");
    outputB.subscopeStrong("struct B");
    outputA.output(outputB);

    assertEq("int x;\n\nstruct B\n{\n}", outputA.data());

    outputC.singleLine("int y;");
    outputC.output(outputA);

    assertEq("int y;\nint x;\n\nstruct B\n{\n}", outputC.data());
}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();
    Output outputC = new Output();
    Output outputD = new Output();

    outputA.subscopeStrong("struct A") in {
        outputB.singleLine("int x;");
        outputC.singleLine("int y;");
        outputD.subscopeStrong("struct B");

        outputA.output(outputB);
        outputA.output(outputC);
        outputA.output(outputD);

        outputA.subscopeStrong("struct C");
    };

    assertEq(q"D
struct A
{
    int x;
    int y;

    struct B
    {
    }

    struct C
    {
    }
}
D", outputA.data("\n"));

}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();
    Output outputC = new Output();

    outputA.subscopeStrong("struct A") in {
        outputB.subscopeStrong("struct B");
        outputC.singleLine("int a;");

        outputA.output(outputB);
        outputA.output(outputC);

        outputA.singleLine("int y;");
    };

    assertEq(q"D
struct A
{
    struct B
    {
    }

    int a;
    int y;
}
D", outputA.data("\n"));

}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();
    Output outputC = new Output();

    outputB.subscopeStrong("struct B") in {
        outputC.subscopeStrong("struct C");
        outputB.output(outputC);
    };

    outputA.subscopeStrong("struct A") in {
        outputA.output(outputB);
    };

    assertEq(q"D
struct A
{
    struct B
    {
        struct C
        {
        }
    }
}
D", outputA.data("\n"));

}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();
    Output outputC = new Output();

    outputA.subscopeStrong("struct Foo");
    outputA.subscopeStrong("struct Bar");
    outputC.output(outputA);

    outputB.singleLine("extern (Objective-C):");
    outputB.separator();

    outputB.output(outputC);

    assertEq(q"D
extern (Objective-C):

struct Foo
{
}

struct Bar
{
}
D", outputB.data("\n"));

}

// Incremental append tests.
unittest
{
    Output output = new Output();

    output.singleLine("%s %s", "int", "x");
    output.append(";");

    assertEq(output.data, "int x;");
}

unittest
{
    Output output = new Output();

    output.append("%s %s", "int", "x");
    output.append(";");

    assertEq(output.data, "int x;");
}

// Flushing comments tests.
unittest
{
    CommentIndex index = makeCommentIndex(
q"C

/* 1, 1, 1 */

/* 4, 1, 16 */
/* 5, 1, 31 */


/* 8, 1, 48 */ /* 8, 16, 63 */

/* 10, 1, 80 */
C");

    Output output = new Output(index);

    output.flushLocation(4, 15, 30, 4, 15, 30);

    assertEq(q"D

/* 1, 1, 1 */

/* 4, 1, 16 */
D", output.data, false);

    output.flushLocation(5, 15, 45, 5, 15, 45);

    assertEq(q"D

/* 1, 1, 1 */

/* 4, 1, 16 */
/* 5, 1, 31 */
D", output.data, false);

    output.flushLocation(8, 15, 62, 8, 15, 62);

    assertEq(q"D

/* 1, 1, 1 */

/* 4, 1, 16 */
/* 5, 1, 31 */

/* 8, 1, 48 */
D", output.data, false);

    output.flushLocation(10, 16, 95, 10, 16, 95);

    assertEq(q"D

/* 1, 1, 1 */

/* 4, 1, 16 */
/* 5, 1, 31 */

/* 8, 1, 48 */ /* 8, 16, 63 */

/* 10, 1, 80 */
D", output.data, false);

}

// There should be no linefeed before first comment,
// if there is no linefeed in the source.
unittest
{
    CommentIndex index = makeCommentIndex(
q"C
/* 1, 1, 1 */

/* 4, 1, 16 */
/* 5, 1, 31 */
C");

    Output output = new Output(index);

    output.flushLocation(3, 15, 29, 3, 15, 29);

    assertEq(q"D
/* 1, 1, 1 */

/* 4, 1, 16 */
D"[0..$-1], output.data);

}

// Keep spaces between comments and non-comments,
// if they were present in original code.
unittest
{
    CommentIndex index = makeCommentIndex(
q"C
/* 1, 1, 0 */

#define FOO_3_1_15 1
/* 4, 1, 34 */
#define BAR_5_1_49 2

/* 7, 1, 69 */ /* 7, 16, 84 */
struct BAZ_8_1_100 { };

C");

    Output output = new Output(index);

    output.flushLocation(3, 1, 15, 3, 21, 35);
    output.singleLine("enum FOO_3_1_15 = 1;");

    assertEq(q"D
/* 1, 1, 0 */

enum FOO_3_1_15 = 1;
D", output.data, false);

    output.flushLocation(5, 1, 51, 5, 21, 71);
    output.singleLine("enum BAR_5_1_49 = 2;");

    assertEq(q"D
/* 1, 1, 0 */

enum FOO_3_1_15 = 1;
/* 4, 1, 34 */
enum BAR_5_1_49 = 2;
D", output.data, false);

    output.flushLocation(8, 1, 104, 8, 23, 126);
    output.subscopeStrong("struct BAZ_8_1_100");

    assertEq(q"D
/* 1, 1, 0 */

enum FOO_3_1_15 = 1;
/* 4, 1, 34 */
enum BAR_5_1_49 = 2;

/* 7, 1, 69 */ /* 7, 16, 84 */
struct BAZ_8_1_100
{
}
D", output.data, false);

}

// Keep space between single-line statements, it they are present in the source.
unittest {
    CommentIndex index = makeCommentIndex(
q"C

#define FOO 1

#define BAR 2

C");

    Output output = new Output(index);

    output.flushLocation(2, 1, 1, 2, 14, 14);
    output.singleLine("enum FOO = 1;");

    assertEq(q"D

enum FOO = 1;
D", output.data, false);

    output.flushLocation(4, 1, 16, 4, 14, 29);
    output.singleLine("enum BAR = 2;");

    assertEq(q"D

enum FOO = 1;

enum BAR = 2;
D", output.data, false);

}

unittest {
    CommentIndex index = makeCommentIndex(
q"C

#define FOO 1
#define BAR 2

C");

    Output output = new Output(index);

    output.flushLocation(2, 1, 1, 2, 14, 14);
    output.singleLine("enum FOO = 1;");

    assertEq(q"D

enum FOO = 1;
D", output.data, false);

    output.flushLocation(3, 1, 15, 3, 14, 28);
    output.singleLine("enum BAR = 2;");

    assertEq(q"D

enum FOO = 1;
enum BAR = 2;
D", output.data, false);

}

// Do not insert additional space between single-line statement and
// block-statement, even if there is extra space in the original.
unittest {
    CommentIndex index = makeCommentIndex(
q"C

int func(int x);


struct A {
    int field;
};
C");

    Output output = new Output(index);

    output.flushLocation(2, 1, 1, 2, 16, 16);
    output.singleLine("int func(int x);");

    assertEq(q"D

int func(int x);
D", output.data, false);

    output.flushLocation(5, 1, 20, 7, 2, 50, false);
    output.subscopeStrong("struct A") in {
        output.singleLine("int field;");
    };

    assertEq(q"D

int func(int x);

struct A
{
    int field;
}
D", output.data, false);

}

// Test saving header position.
unittest
{
    CommentIndex index = makeCommentIndex(
q"C
/* This is header comment.
 * Aaaaaaaaaaaaaaaaaaaaaaa.
 * Aaaaaaaaaaaaaa. Aaaaaa.
 */

int func(int x);

struct A { };
C");

    Output output = new Output(index);

    output.flushHeaderComment();
    output.flushLocation(6, 1, 87, 6, 17, 103);
    output.singleLine("int func(int x);");
    output.flushLocation(8, 1, 105, 10, 3, 136, false);
    output.subscopeStrong("struct A");

    assertEq(q"D
/* This is header comment.
 * Aaaaaaaaaaaaaaaaaaaaaaa.
 * Aaaaaaaaaaaaaa. Aaaaaa.
 */

int func(int x);

struct A
{
}
D", output.data, false);

    assertEq(q"D
/* This is header comment.
 * Aaaaaaaaaaaaaaaaaaaaaaa.
 * Aaaaaaaaaaaaaa. Aaaaaa.
 */

D", output.header);

    assertEq(q"D
int func(int x);

struct A
{
}
D"[0..$-1], output.content);
}

unittest
{
    auto output = new Output(null, 20, 4);

    output.adaptiveLine("");

    assertEq(q"D
D", output.data);

    output.adaptiveLine("int func();");

    assertEq(q"D

int func();
D"[0..$-1], output.data);

}

// Test empty adaptiveLine.
unittest
{
    auto output = new Output();
    output.adaptiveLine("");
    assertEq("", output.data);
    output.adaptiveLine("");
    output.adaptiveLine("");
    assertEq("\n\n", output.data);
}

// Test adding separators in one line.
unittest
{
    auto output = new Output();

    output.adaptiveLine("void func(%@,%@)") in {
        output.adaptiveLine("int foo");
        output.adaptiveLine("int bar");
    };

    assertEq("void func(int foo, int bar)", output.data);
}

// Test adding separators in multiple lines.
unittest
{
    auto output = new Output(null, 32);

    output.adaptiveLine("void func(%@,%@)") in {
        output.adaptiveLine("int a");
        output.adaptiveLine("int b");
        output.adaptiveLine("int c");
        output.adaptiveLine("int d");
        output.adaptiveLine("int e");
    };

    assertEq(q"D
void func(
    int a,
    int b,
    int c,
    int d,
    int e)
D"[0..$-1], output.data);

}

// Test adding separators with one level of nesting,
// the nested content is one-liner.
unittest
{
    auto output = new Output(null, 32);

    output.adaptiveLine("void func(%@,%@)") in {
        output.adaptiveLine("int a");
        output.adaptiveLine("int b");
        output.adaptiveLine("T!(%@;%@)") in {
            output.adaptiveLine("fooooooo");
            output.adaptiveLine("baaaaaar");
        };
        output.adaptiveLine("int d");
        output.adaptiveLine("int e");
    };

    assertEq(q"D
void func(
    int a,
    int b,
    T!(fooooooo; baaaaaar),
    int d,
    int e)
D"[0..$-1], output.data);

}

// Test adding separators with one level of nesting,
// the nested content is multi-line.
unittest
{
    auto output = new Output(null, 32);

    output.adaptiveLine("void func(%@,%@)") in {
        output.adaptiveLine("int a");
        output.adaptiveLine("int b");
        output.adaptiveLine("T!(%@;%@)") in {
            output.adaptiveLine("fooooooo");
            output.adaptiveLine("baaaaaar");
            output.adaptiveLine("baaaaaaz");
        };
        output.adaptiveLine("int d");
        output.adaptiveLine("int e");
    };

    assertEq(q"D
void func(
    int a,
    int b,
    T!(
        fooooooo;
        baaaaaar;
        baaaaaaz),
    int d,
    int e)
D"[0..$-1], output.data);

}



