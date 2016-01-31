/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Util;

import std.conv;
import std.stdio;

import mambo.core._;

import clang.c.Index;

immutable(char*)* strToCArray (string[] arr)
{
    if (!arr)
        return null;

    immutable(char*)[] cArr;
    cArr.reserve(arr.length);

    foreach (str ; arr)
        cArr ~= str.toStringz;

    return cArr.ptr;
}

string toD (CXString cxString)
{
    auto cstr = clang_getCString(cxString);
    auto str = to!(string)(cstr).idup;
    clang_disposeString(cxString);

    return str;
}

template isCX (T)
{
    enum bool isCX = __traits(hasMember, T, "cx");
}

template cxName (T)
{
    enum cxName = "CX" ~ T.stringof;
}

U* toCArray (U, T) (T[] arr)
{
    if (!arr)
        return null;

    static if (is(typeof(T.init.cx)))
        return arr.map!(e => e.cx).toArray.ptr;

    else
        return arr.ptr;
}

mixin template CX ()
{
    mixin("private alias " ~ cxName!(typeof(this)) ~ " CType;");

    CType cx;
    alias cx this;

    void dispose ()
    {
        enum methodCall = "clang_dispose" ~ typeof(this).stringof ~ "(cx);";

        static if (false && __traits(compiles, methodCall))
            mixin(methodCall);
    }

    @property bool isValid ()
    {
        return cx !is CType.init;
    }
}

extern (C) int mkstemps(char*, int);
extern (C) int close(int);

class NamedTempFileException : object.Exception
{
    this (string message, string file = __FILE__, size_t line = __LINE__)
    {
        super(message, file, line);
    }
}

File namedTempFile(string prefix, string suffix) 
{
    import std.random;
    import std.file;
    import std.path;
    import std.format;

    void randstr (char[] slice)
    {
        for (uint i = 0; i < slice.length; ++i)
            slice[i] = uniform!("[]")('A', 'Z');
    }

    string name = format("%sXXXXXXXXXXXXXXXX%s\0", prefix, suffix);
    char[] path = buildPath(tempDir(), name).dup;
    const size_t termAnd6XSize = 7;
    randstr(path[$ - name.length + prefix.length .. $ - suffix.length - termAnd6XSize]);

    int fd = mkstemps(path.ptr, cast(int) suffix.length);
    scope (exit) close(fd);

    if (fd == -1)
        throw new NamedTempFileException("Cannot create \"%s\" temporary file.".format(path));

    return File(path[0..$-1], "wb+");
}
