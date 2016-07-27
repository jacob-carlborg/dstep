/**
 * Copyright: Copyright (c) 2015 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 31, 2015
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Compiler;

import std.path;
import std.typetuple : staticMap;

import clang.c.Index;

struct Compiler
{
    private
    {
        version (Windows)
            enum root = `C:\`;

        else
            enum root = "/";

        string virtualPath_;

        static template toInternalHeader (string file)
        {
            enum toInternalHeader = InternalHeader(file, import(file));
        }

        static struct InternalHeader
        {
            string filename;
            string content;
        }

        enum internalHeaders = [staticMap!(toInternalHeader,
            "float.h", "stdarg.h", "stddef.h")];
    }

    string[] extraIncludePaths ()
    {
        return [virtualPath];
    }

    CXUnsavedFile[] extraHeaders ()
    {
        import std.algorithm : map;
        import std.array;
        import std.string : toStringz;

        return internalHeaders.map!((e) {
            auto path = buildPath(virtualPath, e.filename);
            return CXUnsavedFile(path.toStringz, e.content.ptr, e.content.length);
        }).array();
    }

private:

    string virtualPath ()
    {
        import std.random;
        import std.conv;

        if (virtualPath_.length)
            return virtualPath_;

        return virtualPath_ = buildPath(root, uniform(1, 10_000_000).to!string);
    }
}
