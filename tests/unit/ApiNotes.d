/**
 * Copyright: Copyright (c) 2024 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 5, 2024
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import std.exception;
import std.format;

import Common;
import dstep.core.Optional;
import dstep.translator.ApiNotes;
import dstep.translator.Options;

@"Function.parse"
{
    @"plain rename" unittest
    {
        auto rawFunction = RawFunction(name: "foo", dName: "bar");
        auto expected = Function(name: "foo", baseName: "bar");
        auto actual = Function.parse(rawFunction);

        assert(actual == expected, format!"%s != %s"(actual, expected));
    }

    @"with context" unittest
    {
        auto rawFunction = RawFunction(name: "foo", dName: "a.b");
        auto expected = Function(name: "foo", context: some("a"), baseName: "b");
        auto actual = Function.parse(rawFunction);

        assert(actual == expected, format!"%s != %s"(actual, expected));
    }

    @"with arguments"
    {
        unittest
        {
            auto rawFunction = RawFunction(name: "foo", dName: "bar(a:b:)");
            auto expected = Function(name: "foo", baseName: "bar", arguments: ["a", "b"]);
            auto actual = Function.parse(rawFunction);

            assert(actual == expected, format!"%s != %s"(actual, expected));
        }

        @"With const" unittest
        {
            auto rawFunction = RawFunction(name: "foo", dName: "a.b(x:y:)");
            auto actual = Function.parse(rawFunction);

            auto expected = Function(
                name: "foo",
                context: some("a"),
                baseName: "b",
                arguments: ["x", "y"]
            );

            assert(actual == expected, format!"%s != %s"(actual, expected));
        }
    }

    @"with invalid base name" unittest
    {
        auto rawFunction = RawFunction(name: "foo", dName: "3bar");
        assertThrown!InvalidIdentifierException(Function.parse(rawFunction));
    }

    @"with invalid context" unittest
    {
        auto rawFunction = RawFunction(name: "foo", dName: "3a.b");
        assertThrown!InvalidIdentifierException(Function.parse(rawFunction));
    }

    @"with invalid signature"
    {
        unittest
        {
            auto rawFunction = RawFunction(name: "foo", dName: "bar(");
            assertThrown!InvalidSignatureException(Function.parse(rawFunction));
        }

        unittest
        {
            auto rawFunction = RawFunction(name: "foo", dName: "bar)");
            assertThrown!InvalidSignatureException(Function.parse(rawFunction));
        }
    }
}

@"ApiNotes.lookupFunction"
{
    unittest
    {
        auto doc = ApiNotes.ApiNotes([RawFunction(name: "foo", dName: "bar")]);
        assert(doc.lookupFunction("foo").isPresent);
    }
}

@"ApiNotes.contextExists" unittest
{
    auto apiNotes = ApiNotes.ApiNotes([
        RawFunction(name: "foo", dName: "Bar.baz")
    ]);

    assert(apiNotes.contextExists("Bar"));
}

@"ApiNotes.parse" unittest
{
    enum apiNotesData =
q"YAML
Functions:
  - Name: foo
    DName: bar
YAML";

    auto actual = ApiNotes.ApiNotes.parse(apiNotesData);
    auto expected = ApiNotes.ApiNotes([RawFunction(name: "foo", dName: "bar")]);

    assert(actual == expected, format!"%s != %s"(actual, expected));
}

@"Function.isInstanceMethod"
{
    @"when the D name contains a context"
    {
        @"when the D name contains a 'this'" unittest
        {
            auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar(this)");
            auto func = Function.parse(rawFunc);

            assert(func.isInstanceMethod);
        }

        @"when the D name contains a 'self'" unittest
        {
            auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar(self)");
            auto func = Function.parse(rawFunc);

            assert(func.isInstanceMethod);
        }

        @"when the D name does not contain 'this' or 'self'" unittest
        {
            auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar()");
            auto func = Function.parse(rawFunc);

            assert(!func.isInstanceMethod);
        }
    }

    @"when the D name does not contain a context" unittest
    {
        auto rawFunc = RawFunction(name: "foo", dName: "bar");
        auto func = Function.parse(rawFunc);

        assert(!func.isInstanceMethod);
    }
}

@"Function.isStaticMethod"
{
    @"when the D name contains a context"
    {
        @"when the D name contains a 'this'" unittest
        {
            auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar(this)");
            auto func = Function.parse(rawFunc);

            assert(!func.isStaticMethod);
        }

        @"when the D name contains a 'self'" unittest
        {
            auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar(self)");
            auto func = Function.parse(rawFunc);

            assert(!func.isStaticMethod);
        }

        @"when the D name does not contain 'this' or 'self'" unittest
        {
            auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar()");
            auto func = Function.parse(rawFunc);

            assert(func.isStaticMethod);
        }
    }

    @"when the D name does not contain a context" unittest
    {
        auto rawFunc = RawFunction(name: "foo", dName: "bar");
        auto func = Function.parse(rawFunc);

        assert(!func.isStaticMethod);
    }
}

@"renaming free function" unittest
{
    auto options = Options(apiNotes:
q"YAML
Functions:
  - Name: foo
    DName: bar
YAML"
);

    assertTranslates(
q"C
void foo();
C",
q"D
extern (C):

pragma(mangle, "foo") void bar ();
D", options);
}

@"free function to instance method"
{
    @"when the first parameter is not a pointer" unittest
    {
        auto options = Options(apiNotes:
q"YAML
Functions:
  - Name: foo
    DName: Bar.foo(this:a:)
YAML"
);

        assertTranslatesAnnotated(
q"C
struct Bar {};

void foo(struct Bar bar, int a);
C",
q"D
struct Bar
{
    void foo (int a)
    {
        return __foo(this, __traits(parameters));
    }

    extern (C) private static
    pragma(mangle, "foo") void __foo (Bar bar, int a);
}
D", options, annotatedFile: "Bar.d");
    }

    @"when the first parameter is pointer" unittest
    {
        auto options = Options(apiNotes:
q"YAML
Functions:
  - Name: foo
    DName: Bar.foo(this:a:)
YAML"
);

        assertTranslatesAnnotated(
q"C
struct Bar {};

void foo(struct Bar* bar, int a);
C",
q"D
struct Bar
{
    void foo (int a)
    {
        return __foo(&this, __traits(parameters));
    }

    extern (C) private static
    pragma(mangle, "foo") void __foo (Bar* bar, int a);
}
D", options, annotatedFile: "Bar.d");
    }
}

@"free function to static method" unittest
{
    auto options = Options(apiNotes:
q"YAML
Functions:
  - Name: foo
    DName: Bar.foo(a:)
YAML"
);

    assertTranslatesAnnotated(
q"C
struct Bar {};

void foo(int a);
C",
q"D
struct Bar
{
    extern (C) pragma(mangle, "foo")
    static void foo (int a);
}
D", options, annotatedFile: "Bar.d");
}
