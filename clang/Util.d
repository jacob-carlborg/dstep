/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Util;

import std.conv;
import std.stdio;
import std.format;

import clang.c.Index;

immutable(char*)* strToCArray (const string[] arr)
{
    import std.string : toStringz;

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

string clangVersionString()
{
    import std.string : strip;

    return strip(clang_getClangVersion().toD);
}

struct Version
{
    uint major = 0;
    uint minor = 0;
    uint release = 0;
}

Version clangVersion()
{
    import std.algorithm : find;
    import std.conv : parse;
    import std.ascii : isDigit;
    import std.range;

    Version result;
    auto verstr = clangVersionString().find!(x => x.isDigit);

    result.major = verstr.parse!uint;
    verstr.popFront();
    result.minor = verstr.parse!uint;
    verstr.popFront();

    if (!verstr.empty && verstr.back.isDigit)
        result.release = verstr.parse!uint;

    return result;
}

alias Set(T) = void[0][T];

void add(T)(ref void[0][T] self, T value) {
    self[value] = (void[0]).init;
}

void add(T)(ref void[0][T] self, void[0][T] set) {
    foreach (key; set.byKey) {
        self.add(key);
    }
}

Set!T clone(T)(ref void[0][T] self) {
    Set!T result;
    result.add(self);
    return result;
}

bool contains(T)(inout(void[0][T]) set, T value) {
    return (value in set) !is null;
}

auto setFromList(T)(T[] list)
{
    import std.traits;

    Set!(Unqual!T) result;

    foreach (item; list)
        result.add(item);

    return result;
}

version (Posix)
{
    private extern (C) int mkstemps(char*, int);
    private extern (C) int close(int);
}
else
{
    struct GUID {
        uint Data1;
        ushort Data2;
        ushort Data3;
        ubyte[8] Data4;
    }

    private extern (Windows) uint CoCreateGuid(GUID* pguid);

    string createGUID()
    {
        char toHex(uint x)
        {
            if (x < 10)
                return cast(char) ('0' + x);
            else
                return cast(char) ('A' + x - 10);
        }

        GUID guid;
        CoCreateGuid(&guid);

        ubyte* data = cast(ubyte*)&guid;
        char[32] result;

        foreach (i; 0 .. 16)
        {
            result[i * 2 + 0] = toHex(data[i] & 0x0fu);
            result[i * 2 + 1] = toHex(data[i] >> 16);
        }

        return result.idup;
    }
}

class NamedTempFileException : object.Exception
{
    immutable string path;

    this (string path, string file = __FILE__, size_t line = __LINE__)
    {
        this.path = path;
        super(format("Cannot create temporary file \"%s\".", path), file, line);
    }
}

File namedTempFile(string prefix, string suffix)
{
    import std.file;
    import std.path;
    import std.format;

    version (Posix)
    {
        static void randstr (char[] slice)
        {
            import std.random;

            foreach (i; 0 .. slice.length)
                slice[i] = uniform!("[]")('A', 'Z');
        }

        string name = format("%sXXXXXXXXXXXXXXXX%s\0", prefix, suffix);
        char[] path = buildPath(tempDir(), name).dup;
        const size_t termAnd6XSize = 7;

        immutable size_t begin = path.length - name.length + prefix.length;
        immutable size_t end = path.length - suffix.length - termAnd6XSize;

        randstr(path[begin .. end]);

        int fd = mkstemps(path.ptr, cast(int) suffix.length);
        scope (exit) close(fd);

        path = path[0 .. $ - 1];

        if (fd == -1)
            throw new NamedTempFileException(path.idup);

        return File(path, "wb+");
    }
    else
    {
        string name = format("%s%s%s", prefix, createGUID(), suffix);
        string path = buildPath(tempDir(), name);
        return File(path, "wb+");
    }
}

string asAbsNormPath(string path)
{
    import std.path;
    import std.conv : to;

    return to!string(path.asAbsolutePath.asNormalizedPath);
}
