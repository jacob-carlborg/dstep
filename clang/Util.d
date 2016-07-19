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

immutable(char*)* strToCArray (const string[] arr)
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

alias Set(T) = void[0][T];

void add(T)(ref void[0][T] set, T value) {
    set[value] = (void[0]).init;
}

bool contains(T)(inout(void[0][T]) set, T value) {
    return (value in set) !is null;
}

Set!T SetFromList(T)(T[] list)
{
    Set!T = result;

    foreach (item; list)
        result.add(item);

    return result;
}

extern (C) int mkstemps(char*, int);
extern (C) char* mkdtemp(char*);
extern (C) int close(int);

class NamedTempFileException : object.Exception
{
    immutable string path;

    this (string path, string file = __FILE__, size_t line = __LINE__)
    {
        this.path = path;
        super(format("Cannot create temporary file \"%s\".", path), file, line);
    }
}

class NamedTempDirException : object.Exception
{
    immutable string path;

    this (string path, string file = __FILE__, size_t line = __LINE__)
    {
        this.path = path;
        super(
            format("Cannot create temporary directory \"%s\".", path),
            file,
            line);
    }
}

private void randstr (char[] slice)
{
    import std.random;

    foreach (i; 0 .. slice.length)
        slice[i] = uniform!("[]")('A', 'Z');
}

File namedTempFile(string prefix, string suffix)
{
    import std.file;
    import std.path;
    import std.format;

    string name = format("%sXXXXXXXXXXXXXXXX%s\0", prefix, suffix);
    char[] path = buildPath(tempDir(), name).dup;
    const size_t termAnd6XSize = 7;

    immutable size_t begin = path.length - name.length + prefix.length;
    immutable size_t end = path.length - suffix.length - termAnd6XSize;

    randstr(path[begin .. end]);

    int fd = mkstemps(path.ptr, cast(int) suffix.length);
    scope (exit) close(fd);

    path = path[0..$-1];

    if (fd == -1)
        throw new NamedTempFileException(path.idup);

    return File(path, "wb+");
}

string namedTempDir(string prefix)
{
    import std.file;
    import std.path;
    import std.format;

    string name = format("%sXXXXXXXXXXXXXXXX\0", prefix);
    char[] path = buildPath(tempDir(), name).dup;
    const size_t termAnd6XSize = 7;

    immutable size_t begin = path.length - name.length + prefix.length;

    randstr(path[begin .. $ - termAnd6XSize]);

    char* result = mkdtemp(path.ptr);

    path = path[0..$-1];

    if (result == null)
        throw new NamedTempDirException(path.idup);

    return path.idup;
}
