/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: October 02, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.ConvertCase;

auto splitSpelling(string spelling)
{
    import std.algorithm;
    import std.ascii;
    import std.range;

    struct Range
    {
        private string spelling;
        private string next;
        private bool capitals;

        this(string spelling)
        {
            this.spelling = spelling.stripLeft('_');
            capitals = !spelling.canFind!isLower;
            popFront();
        }

        bool empty() const
        {
            return next.empty;
        }

        string front() const
        {
            return next;
        }

        void popFront()
        {
            if (spelling.empty)
            {
                next = spelling;
            }
            else
            {
                size_t end = capitals
                    ? spelling[1 .. $].countUntil!(a => a == '_')
                    : spelling[1 .. $].countUntil!(
                        a => !a.isLower && !a.isDigit);

                end = end == -1 ? spelling.length : end + 1;
                next = spelling[0 .. end];
                spelling = spelling[end .. $].stripLeft('_');
            }
        }
    }

    return Range(spelling);
}

unittest
{
    import std.array;

    assert(splitSpelling("").array == []);
    assert(splitSpelling("__").array == []);
    assert(splitSpelling("x").array == ["x"]);
    assert(splitSpelling("X").array == ["X"]);
    assert(splitSpelling("xxx").array == ["xxx"]);
    assert(splitSpelling("xxxXxx").array == ["xxx", "Xxx"]);
    assert(splitSpelling("xxxXxxYyy").array == ["xxx", "Xxx", "Yyy"]);
    assert(splitSpelling("xxxXxxYYY").array == ["xxx", "Xxx", "Y", "Y", "Y"]);
    assert(splitSpelling("xxx_Xxx__YYY").array == ["xxx", "Xxx", "Y", "Y", "Y"]);
    assert(splitSpelling("__xxx_Xxx__YYY__").array == ["xxx", "Xxx", "Y", "Y", "Y"]);
    assert(splitSpelling("YYY").array == ["YYY"]);
    assert(splitSpelling("Y_Y__XXY").array == ["Y", "Y", "XXY"]);
    assert(splitSpelling("__Y_Y__XXY__").array == ["Y", "Y", "XXY"]);

    assert(splitSpelling("xyz0").array == ["xyz0"]);
}

string toCamelCase(string spelling)
{
    import std.algorithm;
    import std.array;
    import std.ascii;
    import std.math;

    auto split = spelling.splitSpelling();

    if (split.empty)
    {
        return string.init;
    }
    else
    {
        char[] camelCase(string x)
        {
            return (cast(char) x[0].toUpper) ~
                x[1 .. $].map!(x => cast(char) x.toLower).array;
        }

        char[] front;

        while (split.front.length == 1)
        {
            front ~= cast(char) split.front.front.toLower;
            split.popFront();
        }

        if (front.empty)
        {
            front = split.front.map!(x => cast(char) x.toLower).array;
            split.popFront();
        }

        return (front ~ split.map!camelCase.join).idup;
    }
}

unittest
{
    import std.array;

    assert("".toCamelCase() == "");
    assert("x".toCamelCase() == "x");
    assert("X".toCamelCase() == "x");
    assert("xy".toCamelCase() == "xy");
    assert("xy_zw".toCamelCase() == "xyZw");
    assert("xyZw".toCamelCase() == "xyZw");
    assert("XY_ZW".toCamelCase() == "xyZw");
    assert("XXXy_ZW".toCamelCase() == "xxXyZW");
    assert("XXy_ZW".toCamelCase() == "xXyZW");
}

string toSnakeCase(string spelling)
{
    import std.algorithm;
    import std.range;
    import std.uni;
    import std.utf;

    auto split = spelling.splitSpelling();

    if (split.empty)
    {
        return string.init;
    }
    else
    {
        char[] front;

        while (split.front.length == 1)
        {
            front ~= cast(char) split.front.front.toLower;
            split.popFront();
        }

        if (front.empty)
        {
            front = split.front.dup;
            split.popFront();
        }

        return chain(only(front), split).join('_').map!toLower.toUTF8();
    }
}

unittest
{
    import std.array;

    assert("".toSnakeCase() == "");
    assert("x".toSnakeCase() == "x");
    assert("X".toSnakeCase() == "x");
    assert("xy".toSnakeCase() == "xy");
    assert("xy_zw".toSnakeCase() == "xy_zw");
    assert("xyZw".toSnakeCase() == "xy_zw");
    assert("XY_ZW".toSnakeCase() == "xy_zw");
    assert("XXXy_ZW".toSnakeCase() == "xx_xy_z_w");
    assert("XXy_ZW".toSnakeCase() == "x_xy_z_w");
}
