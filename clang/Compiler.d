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
        string[] sysRootFlag_;

        static template toInternalHeader (string file)
        {
            enum toInternalHeader = InternalHeader(file, import(file));
        }

        static struct InternalHeader
        {
            string filename;
            string content;
        }

        enum internalHeaders_ = [
            staticMap!(
                toInternalHeader,
                "__stddef_max_align_t.h",
                "float.h",
                "limits.h",
                "stdarg.h",
                "stdbool.h",
                "stddef.h"
            )
        ];
    }

    string[] internalFlags ()
    {
        import std.algorithm : map;
        import std.array : array;
        import std.range : chain;

        return extraIncludePaths
            .map!(path => "-I" ~ path)
            .chain(sysRootFlag)
            .array;
    }

    CXUnsavedFile[] internalHeaders ()
    {
        import std.algorithm : map;
        import std.array : array;
        import std.string : toStringz;

        return internalHeaders_.map!((e) {
            auto path = buildPath(virtualPath, e.filename);
            return CXUnsavedFile(path.toStringz, e.content.ptr, cast(uint)e.content.length);
        }).array();
    }

private:

    string[] extraIncludePaths ()
    {
        return [virtualPath];
    }

    string virtualPath ()
    {
        import std.random;
        import std.conv;

        if (virtualPath_.length)
            return virtualPath_;

        return virtualPath_ = buildPath(root, uniform(1, 10_000_000).to!string);
    }

    string[] sysRootFlag ()
    {
        if (sysRootFlag_.length)
            return sysRootFlag_;

        version (OSX)
        {
            import std.string : strip;
            import std.array : join;
            import std.format : format;
            import std.process : execute;

            import dstep.core.Exceptions : DStepException;

            static immutable command = ["xcrun", "--show-sdk-path", "--sdk", "macosx"];
            const result = execute(command);

            if (result.status == 0)
                return sysRootFlag_ = ["-isysroot", result.output.strip];

            enum fmt = "Failed get the path of the SDK.\nThe command '%s' " ~
                "returned the following output:\n%s";

            const message = format!fmt(command.join(" "), result.output);
            throw new DStepException(message);
        }

        else
            return null;
    }
}
