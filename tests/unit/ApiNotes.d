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

@"Function.isConstructor"
{
    @"when the D name contains 'init'" unittest
    {
        auto rawFunc = RawFunction(name: "CreateFoo", dName: "Foo.init()");
        auto func = Function.parse(rawFunc);

        assert(func.isConstructor);
    }

    @"when the D name contains 'this'" unittest
    {
        auto rawFunc = RawFunction(name: "CreateFoo", dName: "Foo.this()");
        auto func = Function.parse(rawFunc);

        assert(func.isConstructor);
    }

    @"when the D name does not contain 'init or 'this'" unittest
    {
        auto rawFunc = RawFunction(name: "CreateFoo", dName: "Foo.bar()");
        auto func = Function.parse(rawFunc);

        assert(!func.isConstructor);
    }

    @"when the D name contains 'init' and the first argument is 'self' " unittest
    {
        auto rawFunc = RawFunction(name: "CreateFoo", dName: "Foo.init(self)");
        auto func = Function.parse(rawFunc);

        assert(!func.isConstructor);
    }
}

@"Function.isInstanceMethod"
{
    @"when the D name contains a context"
    {
        @"when the D name of the first argument is 'this'" unittest
        {
            auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar(this:)");
            auto func = Function.parse(rawFunc);

            assert(func.isInstanceMethod);
        }

        @"when the D name of the first argument is 'self'" unittest
        {
            auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar(self:)");
            auto func = Function.parse(rawFunc);

            assert(func.isInstanceMethod);
        }

        @"when the D name of another argument is 'this'" unittest
        {
            auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar(foo:this:bar:)");
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

@"Function.indexOfThis"
{
    @"when the D name contains 'this' or 'self'" unittest
    {
        auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar(foo:this:bar:)");
        auto func = Function.parse(rawFunc);

        assert(func.indexOfThis == 1);
    }

    @"when the D name does not contain 'this' or 'self'" unittest
    {
        auto rawFunc = RawFunction(name: "foo", dName: "Foo.bar(foo:bar:)");
        auto func = Function.parse(rawFunc);

        assert(func.indexOfThis == -1);
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
        return __foo(this, a);
    }

    extern (C) private static pragma(mangle, "foo")
    void __foo (Bar bar, int a);
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
        return __foo(&this, a);
    }

    extern (C) private static pragma(mangle, "foo")
    void __foo (Bar* bar, int a);
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

@"free function to constructor" unittest
{
    auto options = Options(apiNotes:
q"YAML
Functions:
  - Name: CGPathCreateMutable
    DName: CGMutablePath.init()
YAML"
);

    assertTranslatesAnnotated(
q"C
struct CGMutablePath {};

struct CGMutablePath CGPathCreateMutable(void);
C",
q"D
struct CGMutablePath
{
    static CGMutablePath opCall ()
    {
        return CGPathCreateMutable(__traits(parameters));
    }

    extern (C) private static pragma(mangle, "CGPathCreateMutable")
    CGMutablePath CGPathCreateMutable ();
}
D", options, annotatedFile: "CGMutablePath.d");
}

@"extending non-struct type" unittest
{
    auto options = Options(apiNotes:
q"YAML
Functions:
  - Name: CGPathCreateMutable
    DName: CGMutablePathRef.init()
  - Name: CGPathCreateCopy
    SwiftName: CGMutablePathRef.copy(self:)
YAML"
);

    assertTranslatesAnnotated(
q"C
typedef struct CGPath *CGMutablePathRef;
CGMutablePathRef CGPathCreateMutable(void);
CGMutablePathRef CGPathCreateCopy(CGMutablePathRef path);
C",
q"D
struct CGMutablePathRef
{
    private CGPath* __rawValue;

    static CGMutablePathRef opCall ()
    {
        typeof(this) __result = { CGPathCreateMutable(__traits(parameters)) };
        return __result;
    }

    extern (C) private static pragma(mangle, "CGPathCreateMutable")
    CGPath* CGPathCreateMutable ();

    CGMutablePathRef copy ()
    {
        typeof(this) __result = { __copy(this) };
        return __result;
    }

    extern (C) private static pragma(mangle, "CGPathCreateCopy")
    CGPath* __copy (CGMutablePathRef path);
}
D", options, annotatedFile: "CGMutablePathRef.d");
}
