/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import std.stdio;
import Common;
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

    output.subscopeStrong("class A") in {
        output.singleLine("int a;");
        output.singleLine("float b;");
        output.singleLine("void func();");
    };

    assertEq(q"D
class A
{
    int a;
    float b;
    void func();
}
D", output.data("\n"));

    output.subscopeStrong("class B") in {
        output.singleLine("string s;");
    };

    assertEq(q"D
class A
{
    int a;
    float b;
    void func();
}

class B
{
    string s;
}
D", output.data("\n"));

}

// Test multiple nesting.
unittest
{
    Output output = new Output();

    output.subscopeStrong("class B") in {
        output.singleLine("string s;");
    };

    output.subscopeStrong("class C") in {
        output.subscopeStrong("void func1()") in {
            output.subscopeStrong("class B") in {
                output.singleLine("string s;");
            };

            output.singleLine("int a;");
        };

        output.subscopeStrong("void func2()") in {
            output.subscopeStrong("class B") in {
                output.singleLine("string s;");
            };
        };

        output.singleLine("string s;");
    };

    assertEq(q"D
class B
{
    string s;
}

class C
{
    void func1()
    {
        class B
        {
            string s;
        }

        int a;
    }

    void func2()
    {
        class B
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
    output.subscopeStrong("class A");
    assertEq("class A\n{\n}", output.data());
}

// Test subscopeStrong after singleLine.
unittest
{
    Output output = new Output();

    output.singleLine("void foo();");
    output.singleLine("void bar();");
    output.subscopeStrong("class A") in {
        output.singleLine("void bar();");
    };

    assertEq(q"D
void foo();
void bar();

class A
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

    outputA.subscopeStrong("class A");
    outputA.output(outputB);

    assertEq("class A\n{\n}", outputA.data());
}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();
    Output outputC = new Output();

    outputA.subscopeStrong("class A");
    outputB.subscopeStrong("class B");
    outputA.output(outputB);

    assertEq("class A\n{\n}\n\nclass B\n{\n}", outputA.data());

    outputC.singleLine("int x;");
    outputB.output(outputC);

    assertEq("class B\n{\n}\n\nint x;", outputB.data());
}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();
    Output outputC = new Output();

    outputA.singleLine("int x;");
    outputB.subscopeStrong("class B");
    outputA.output(outputB);

    assertEq("int x;\n\nclass B\n{\n}", outputA.data());

    outputC.singleLine("int y;");
    outputC.output(outputA);

    assertEq("int y;\nint x;\n\nclass B\n{\n}", outputC.data());
}

unittest
{
    Output outputA = new Output();
    Output outputB = new Output();
    Output outputC = new Output();
    Output outputD = new Output();

    outputA.subscopeStrong("class A") in {
        outputB.singleLine("int x;");
        outputC.singleLine("int y;");
        outputD.subscopeStrong("class B");

        outputA.output(outputB);
        outputA.output(outputC);
        outputA.output(outputD);

        outputA.subscopeStrong("class C");
    };

    assertEq(q"D
class A
{
    int x;
    int y;

    class B
    {
    }

    class C
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

    outputA.subscopeStrong("class A") in {
        outputB.subscopeStrong("class B");
        outputC.singleLine("int a;");

        outputA.output(outputB);
        outputA.output(outputC);

        outputA.singleLine("int y;");
    };

    assertEq(q"D
class A
{
    class B
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

    outputB.subscopeStrong("class B") in {
        outputC.subscopeStrong("class C");
        outputB.output(outputC);
    };

    outputA.subscopeStrong("class A") in {
        outputA.output(outputB);
    };

    assertEq(q"D
class A
{
    class B
    {
        class C
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

    outputA.subscopeStrong("class Foo");
    outputA.subscopeStrong("class Bar");
    outputC.output(outputA);

    outputB.singleLine("extern (Objective-C):");
    outputB.separator();

    outputB.output(outputC);

    assertEq(q"D
extern (Objective-C):

class Foo
{
}

class Bar
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
