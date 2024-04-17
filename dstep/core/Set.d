/**
 * Copyright: Copyright (c) 2024 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Mar 15, 2024
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.core.Set;

import std.range : isInputRange, ElementType;

Set!(ElementType!Range) set(Range)(Range values)
if (isInputRange!Range)
{
    return Set!(ElementType!Range)(values);
}

struct Set(T)
{
    private alias Value = void[0];
    private alias Key = KeyType!T;

    private alias ByKeyRange = typeof(
        delegate() const { return storage.byKey(); }()
    );

    Value[Key] storage;

    this(const T[] values ...)
    {
        put(values);
    }

    ///
    unittest
    {
        auto set = Set!int(1, 2, 3, 4);
    }

    this(Range)(Range values)
    if (isInputRange!Range && is(ElementType!Range == T))
    {
        put(values);
    }

    ///
    unittest
    {
        import std.range;
        auto set = Set!int(only(1, 2, 3, 4));
    }

    this(const Set set)
    {
        put(set);
    }

    ///
    unittest
    {
        auto a = Set!int(1, 2, 3, 4);
        auto b = Set!int(a);

        assert(a == b);
    }

    void put(const T[] values ...) pure nothrow
    {
        foreach (v; values)
            storage[cast(Key) v] = Value.init;
    }

    ///
    unittest
    {
        Set!int set;
        set.put(1, 2, 3, 4);

        assert(set.length == 4);
    }

    void put(Range)(Range values)
    if (isInputRange!Range && is(ElementType!Range == T))
    {
        foreach (v; values)
            put(v);
    }

    ///
    unittest
    {
        import std.range;

        Set!int set;
        set.put(only(1, 2, 3, 4));

        assert(set.length == 4);
    }

    void put(const Set set) pure nothrow
    {
        foreach (key; set[])
            put(key);
    }

    ///
    unittest
    {
        Set!int a;
        a.put(1);
        a.put(2);

        Set!int b;
        b.put(a);

        assert(b == a);
    }

    bool opBinaryRight(string op)(const T rhs) const
        if (op == "in")
    {
        return (cast(Key) rhs in storage) !is null;
    }

    ///
    unittest
    {
        auto set = Set!int(1, 2);
        assert(2 in set);

        auto o = new Object;
        auto s = Set!Object(o);
        s.put(new Object);

        assert(o in s);
    }

    auto opSlice() const
    {
        return ByKeyRangeWrapper(storage.byKey);
    }

    ///
    unittest
    {
        import std.algorithm : map, canFind;

        auto set = Set!int(1, 2);
        auto range = set[].map!(e => e);

        // cannot compare "range" with another range since the order of a set is
        // not guaranteed.
        assert(range.canFind(1));
        assert(range.canFind(2));
    }

    size_t length() const
    {
        return storage.length;
    }

    ///
    unittest
    {
        auto set = Set!int(1, 2);
        assert(set.length == 2);
    }

    string toString() const
    {
        import std.format;
        return format("Set(%(%s, %))", storage.byKey);
    }

    ///
    unittest
    {
        auto set = Set!int(1, 2);

        const actual = set.toString;
        assert(actual == "Set(1, 2)" || actual == "Set(2, 1)");
    }

    private static struct ByKeyRangeWrapper
    {
        private ByKeyRange range;

        T front()
        {
            return cast(T) range.front();
        }

        void popFront()
        {
            range.popFront();
        }

        bool empty()
        {
            return range.empty();
        }
    }
}

private template KeyType(T)
{
    static if (is(T == class) || is(T == interface))
    {
        static if (__traits(getLinkage, T) == "D" )
            alias KeyType = T;
        else
            alias KeyType = void*;
    }
    else
        alias KeyType = T;
}
