/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Feb 14, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import std.stdio;
import Common;
import dstep.translator.CodeBlock;

unittest
{
    assertEq("\n", compose(CodeBlock("", EndlHint.group, [])));

    auto declInt = CodeBlock("int a;", EndlHint.singleLine, []);
    auto declFloat = CodeBlock("float b;", EndlHint.singleLine, []);
    auto group1 = CodeBlock("", EndlHint.group, [declInt, declFloat]);

    assertEq("int a;\nfloat b;\n\n", compose(group1));

    auto declString = CodeBlock("string s;", EndlHint.singleLine, []);
    auto declFuncDecl = CodeBlock("void func();", EndlHint.singleLine, []);
    auto group2 = CodeBlock("", EndlHint.group, [declString, declFuncDecl]);
    auto group3 = CodeBlock("", EndlHint.group, [group1, group2]);
    assertEq(q"D
int a;
float b;

string s;
void func();

D", compose(group3));

    auto class1 = CodeBlock("class A", EndlHint.subscopeStrong, [declInt, declFloat, declFuncDecl]);
    assertEq(q"D
class A
{
    int a;
    float b;
    void func();
}
D", compose(class1));

    auto class2 = CodeBlock("class B", EndlHint.subscopeStrong, [declString]);
    auto group4 = CodeBlock([class1, class2]);
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

D", compose(group4));

    auto func1 = CodeBlock("void func1()", EndlHint.subscopeStrong, [class2, declInt]);
    auto func2 = CodeBlock("void func2()", EndlHint.subscopeStrong, [class2]);
    auto class3 = CodeBlock("class C", EndlHint.subscopeStrong, [func1, func2, declString]);
    auto group5 = CodeBlock([class2, class3]);
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

D", compose(group5));
}

unittest
{
    auto declA = CodeBlock("int a;", EndlHint.singleLine);
    auto declB = CodeBlock("int b;", EndlHint.singleLine);
    auto declC = CodeBlock("int c = a + b;", EndlHint.singleLine);

    auto if1 = CodeBlock("if (true)", EndlHint.subscopeWeak, [declA]);
    auto if2 = CodeBlock("if (true)", EndlHint.subscopeWeak, [declA, declB]);
    auto if3 = CodeBlock("if (true)", EndlHint.subscopeWeak, [declA, declB, declC]);

    assertEq(q"D
if (true)
    int a;
D", compose(if1));

    assertEq(q"D
if (true)
{
    int a;
    int b;
}
D", compose(if2));

    assertEq(q"D
if (true)
{
    int a;
    int b;
    int c = a + b;
}
D", compose(if3));
}

// Test EndlHint.MultiLine.
unittest
{
    auto callA = CodeBlock("foo();", EndlHint.singleLine);
    auto callB = CodeBlock("bar();", EndlHint.singleLine);
    auto break_ = CodeBlock("break;", EndlHint.singleLine);

    auto case1 = CodeBlock("case UltimateCase:", EndlHint.multiLine, [callA, callB, break_]);

    assertEq(q"D
case UltimateCase:
    foo();
    bar();
    break;
D", compose(case1));

}

// Test EndlHint.SubscopeStrong after EndlHint.SingleLine.
unittest
{
    auto callA = CodeBlock("void foo();", EndlHint.singleLine);
    auto callB = CodeBlock("void bar();", EndlHint.singleLine);
    auto class1 = CodeBlock("class A", EndlHint.subscopeStrong, [callB]);

    auto case1 = CodeBlock([callA, callB, class1]);

    assertEq(q"D
void foo();
void bar();

class A
{
    void bar();
}

D", compose(case1));

}
