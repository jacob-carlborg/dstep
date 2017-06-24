/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Aug 08, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import std.stdio;
import Common;
import dstep.translator.Translator;
import dstep.translator.Enum;

void assertRenameEnumMembers(
    string spelling,
    string[] input,
    string[] expected,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import core.exception;
    import std.algorithm.comparison;
    import std.format;
    import std.range;

    auto actual = renameEnumMembers(spelling, input);

    if (!equal(expected, actual))
    {
        auto formatString = "\nExpected:\n%s\nActual:\n%s\n";
        auto message = format(
            formatString,
            chain([spelling], expected),
            chain([spelling], actual));

        throw new AssertError(message, file, line);
    }
}

unittest
{
    assertRenameEnumMembers(
        "PrefixFoo",
        ["PrefixFOO", "PrefixBAR", "PrefixBAZ"],
        ["FOO", "BAR", "BAZ"]);
}

unittest
{
    assertRenameEnumMembers(
        "CXFooBar",
        ["CXFoo_Baz"],
        ["Baz"]);

    assertRenameEnumMembers(
        "CXFooBar",
        ["CXFoo_Baz", "CXFoo_Qux"],
        ["Baz", "Qux"]);
}

unittest
{
    assertRenameEnumMembers(
        "CXFooBar",
        ["CXFoo_Baz"],
        ["Baz"]);

    assertRenameEnumMembers(
        "CXFooBar",
        ["CXFoo_Baz", "CXFoo_Qux"],
        ["Baz", "Qux"]);
}

unittest
{
    assertRenameEnumMembers(
        "CXFoo_Bar",
        ["CXFoo_Baz"],
        ["Baz"]);

    assertRenameEnumMembers(
        "CXFoo_Bar",
        ["CXFoo_Baz", "CXFoo_Qux"],
        ["Baz", "Qux"]);
}

unittest
{
    assertRenameEnumMembers(
        "CXFoo",
        ["CXFoo_Baz"],
        ["Baz"]);

    assertRenameEnumMembers(
        "CXFoo",
        ["CXFoo_Baz", "CXFoo_Qux"],
        ["Baz", "Qux"]);
}

unittest
{
    assertRenameEnumMembers(
        "CXFoo",
        ["CXFoo_BarBaz", "CXFoo_BarQux"],
        ["BarBaz", "BarQux"]);
}

unittest
{
    assertRenameEnumMembers(
        "CXFuuBar",
        ["CXFu_Baz"],
        ["Baz"]);

    assertRenameEnumMembers(
        "CXFuuBar",
        ["CXFu_Baz", "CXFu_Qux"],
        ["Baz", "Qux"]);
}

unittest
{
    assertRenameEnumMembers(
        "CXFuuBar",
        ["CXFoo_Baz", "CXFoo_Qux"],
        ["Baz", "Qux"]);
}

unittest
{
    assertRenameEnumMembers(
        "CX_FooBar",
        ["CX_FB_Baz", "CX_FB_Qux"],
        ["Baz", "Qux"]);
}

unittest
{
    assertRenameEnumMembers(
        "CXFuuBar",
        ["CXFoo_Baz"],
        ["Baz"]);
}

unittest
{
    assertRenameEnumMembers(
        "CX_FooBar",
        ["CX_FB_Baz"],
        ["Baz"]);
}

unittest
{
    assertRenameEnumMembers(
        "CXFuuBar",
        ["CXFOO_BAZ"],
        ["FOO_BAZ"]);
}

unittest
{
    assertRenameEnumMembers(
        "CX_FooBarBaz",
        ["CX_FB_BazBreak", "CX_FB_BazContinue"],
        ["BazBreak", "BazContinue"]);
}

unittest
{
    assertRenameEnumMembers(
        "CX_FooBarBaz",
        ["CX_FB__BazBreak", "CX_FB__BazContinue"],
        ["BazBreak", "BazContinue"]);
}

unittest
{
    assertRenameEnumMembers(
        "CX_FooBarBaz",
        ["CX__FB_BazBreak", "CX__FB_BazContinue"],
        ["BazBreak", "BazContinue"]);
}

unittest
{
    assertRenameEnumMembers(
        "CX_FooBarBaz",
        ["__FB_BazBreak", "__FB_BazContinue"],
        ["BazBreak", "BazContinue"]);
}

unittest
{
    assertRenameEnumMembers(
        "CX_FooBarBaz",
        ["__BazBreak", "__BazContinue"],
        ["Break", "Continue"]);
}

unittest
{
    Options options;
    options.renameEnumMembers = true;

    assertTranslates(
q"C
enum CX_FooBar
{
    CX_FB_Baz,
    CX_FB_QuxXyz,
};
C",
q"D
extern (C):

enum CX_FooBar
{
    baz = 0,
    quxXyz = 1
}
D", options);

    assertTranslates(
q"C
enum ABFooBarBazReply {
    ABFooBarBazReplySuccess = 0,
    ABFooBarBazReplyCancel = 1,
    ABFooBarBazReplyFailure = 2
};
C",
q"D
extern (C):

enum ABFooBarBazReply
{
    success = 0,
    cancel = 1,
    failure = 2
}
D", options);

    assertTranslates(
q"C
enum CX_FooBar
{
    CX_FB_ASTQuxXyz,
    CX_FB_ASTQuxXYZw,
    CX_FB_UInt,
    CX_FB_C
};
C",
q"D
extern (C):

enum CX_FooBar
{
    astQuxXyz = 0,
    astQuxXYZw = 1,
    uInt = 2,
    c = 3
}
D", options);

    assertTranslates(
q"C
enum CX_FooBar
{
    CX_FB_Break,
    CX_FB_Continue,
};
C",
q"D
extern (C):

enum CX_FooBar
{
    break_ = 0,
    continue_ = 1
}
D", options);

    assertTranslates(
q"C
enum CX_FooBarBaz
{
    CX_FB_BazXxxxx,
    CX_FB_BazYyyyy,
};
C",
q"D
extern (C):

enum CX_FooBarBaz
{
    bazXxxxx = 0,
    bazYyyyy = 1
}
D", options);

}
