/**
 * Copyright: Copyright (c) 2024 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 20, 2024
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.core.Traits;

import std.traits : isAssociativeArray, isDynamicArray, isPointer;

/// Evaluates to `true` if the given type can hold `null`.
template isNullable(T)
{
    enum isNullable = is(T == class) || is(T == interface) ||
        is(T == function) || is(T == delegate) || isAssociativeArray!T ||
        isDynamicArray!T || isPointer!T;
}

///
unittest
{
    assert(isNullable!Object);
    assert(isNullable!(Object.Monitor));
    assert(isNullable!(void function()));
    assert(isNullable!(void delegate()));
    assert(isNullable!(int*));
    assert(!isNullable!int);
}

// /**
//  * Returns `true` if `T` has a field with the given name $(D_PARAM field).
//  *
//  * Params:
//  *  T = the type of the class/struct
//  *  field = the name of the field
//  *
//  * Returns: `true` if `T` has a field with the given name $(D_PARAM field)
//  */
// bool hasField(T, string field)()
// {
//     static foreach (i; 0 .. T.tupleof.length)
//     {
//         static if (nameOfFieldAt!(T, i) == field)
//             return true;
//         else
//             return false;
//     }
// }

template hasField (T, string field)
{
    enum hasField = hasFieldImpl!(T, field, 0);
}

private template hasFieldImpl (T, string field, size_t i)
{
    static if (T.tupleof.length == i)
        enum hasFieldImpl = false;

    else static if (nameOfFieldAt!(T, i) == field)
        enum hasFieldImpl = true;

    else
        enum hasFieldImpl = hasFieldImpl!(T, field, i + 1);
}

///
unittest
{
    static struct Foo
    {
        int bar;
    }

    assert(hasField!(Foo, "bar"));
    assert(!hasField!(Foo, "foo"));
}

/**
 * Evaluates to a string containing the name of the field at given position in the given type.
 *
 * Params:
 *  T = the type of the class/struct
 *  position = the position of the field in the tupleof array
 */
template nameOfFieldAt (T, size_t position)
{
    import std.format : format;

    enum errorMessage = `The given position "%s" is greater than the number ` ~
        `of fields (%s) in the type "%s"`;

    static assert (position < T.tupleof.length, format(errorMessage, position,
        T.tupleof.length, T.stringof));

    enum nameOfFieldAt = __traits(identifier, T.tupleof[position]);
}

///
unittest
{
    static struct Foo
    {
        int foo;
        int bar;
    }

    assert(nameOfFieldAt!(Foo, 1) == "bar");
}

/**
 * Returns `true` if `T` has a member with the given name $(D_PARAM member).
 *
 * Params:
 *  T = the type of the class/struct
 *  member = the name of the member
 *
 * Returns: `true` if `T` has a member with the given name $(D_PARAM member)
 */
bool hasMember(T, string member)()
{
    return __traits(hasMember, T, member);
}

///
unittest
{
    static struct Foo
    {
        int bar;
    }

    assert(hasMember!(Foo, "bar"));
    assert(!hasMember!(Foo, "foo"));
}

/**
 * Evaluates to the type of the member with the given name
 *
 * Params:
 *  T = the type of the class/struct
 *  member = the name of the member
 */
template TypeOfMember (T, string member)
{
    import std.format : format;

    enum errorMessage = `The given member "%s" does not exist in the type "%s"`;

    static if (!hasMember!(T, member))
        static assert(false, format(errorMessage, member, T.stringof));

    else
        alias TypeOfMember = typeof(__traits(getMember, T, member));
}

///
unittest
{
    static struct Foo
    {
        int foo;
    }

    assert(is(TypeOfMember!(Foo, "foo") == int));
    assert(!__traits(compiles, { alias T = TypeOfMember!(Foo, "bar"); }));
}

auto ref getMember(string member, T)(auto ref T value)
{
    enum errorMessage = `The given member "%s" does not exist in the type "%s"`;

    static if (!hasMember!(T, member))
        static assert(false, format(errorMessage, member, T.stringof));
    else
        return __traits(getMember, value, member);
}

unittest
{
    static struct Foo
    {
        int foo;
    }

    assert(Foo(3).getMember!"foo" == 3);
}

/// Detect whether type `T` is an aggregate.
enum isAggregateType(alias T) =
    is(T == struct) ||
    is(T == union) ||
    is(T == class) ||
    is(T == interface);

/// ditto
enum isAggregateType(T) =
    is(T == struct) ||
    is(T == union) ||
    is(T == class) ||
    is(T == interface);

///
@safe unittest
{
    class C;
    union U;
    struct S;
    interface I;

    static assert( isAggregateType!C);
    static assert( isAggregateType!U);
    static assert( isAggregateType!S);
    static assert( isAggregateType!I);
    static assert(!isAggregateType!void);
    static assert(!isAggregateType!string);
    static assert(!isAggregateType!(int[]));
    static assert(!isAggregateType!(C[string]));
    static assert(!isAggregateType!(void delegate(int)));
}

/// Evaluates to `true` if `func` has a `this` reference.
bool hasThisReference(alias func)()
{
    assertCallable!func;

    alias Parent = __traits(parent, func);

    return isAggregateType!Parent && !__traits(isStaticFunction, func);
}

///
@safe unittest
{
    static void foo() {}

    static class Foo
    {
        static void bar() {}
    }

    assert(hasThisReference!(Object.toString));
    assert(!hasThisReference!foo);
    assert(!hasThisReference!(Foo.bar));
}

/// Evaluates to `true` if `func` has a context.
bool hasContext(alias func)()
{
    assertCallable!func;

    static if (is(typeof(func) == delegate))
        return true;
    else static if (is(typeof(*func) == function))
        return false;
    else
        return __traits(isNested, func) || hasThisReference!func;
}

///
@safe unittest
{
    static void noContext() {}
    void context() {}

    class Foo
    {
        static void noContext() {}
        void context() {}
    }

    void delegate() a;
    void function() b;

    assert(hasContext!a);
    assert(hasContext!context);
    assert(hasContext!(Foo.context));

    assert(!hasContext!b);
    assert(!hasContext!noContext);
    assert(!hasContext!(Foo.noContext));
}

/// Evaluates to the `this` type of the given callable symbol.
template ThisType(alias func)
{
    import std.traits : CopyTypeQualifiers, isCallable;

    static assert(hasThisReference!func,
        `The given symbol "` ~ func.stringof ~ `" of type "` ~
        typeof(func).stringof ~ `" does not have a this type`);

    alias ThisType = CopyTypeQualifiers!(typeof(func), __traits(parent, func));
}

///
@safe unittest
{
    static class Expression
    {
        void a() {}
        void b() const {}
        void c() immutable {}
        void d() inout {}

        void aShared() shared {}
        void bShared() shared const {}
        void cShared() shared immutable {}
        void dShared() shared inout {}
    }

    assert(is(ThisType!(Expression.a) == Expression));
    assert(is(ThisType!(Expression.b) == const Expression));
    assert(is(ThisType!(Expression.c) == immutable Expression));
    assert(is(ThisType!(Expression.d) == inout Expression));

    assert(is(ThisType!(Expression.aShared) == shared Expression));
    assert(is(ThisType!(Expression.bShared) == shared const Expression));
    assert(is(ThisType!(Expression.cShared) == shared immutable Expression));
    assert(is(ThisType!(Expression.dShared) == shared inout Expression));
}

private void assertCallable(alias symbol)()
{
    import std.traits : isCallable;

    static assert(isCallable!symbol,
        `The given symbol "` ~ symbol.stringof ~ `" of type "` ~
        typeof(symbol).stringof ~ `" is not callable`);
}
