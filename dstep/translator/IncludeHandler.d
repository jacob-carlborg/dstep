/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jun 15, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.IncludeHandler;

import std.array : Appender;

import clang.c.Index;
import clang.Cursor;
import clang.Util;

import dstep.translator.HeaderIndex;
import dstep.translator.Options;
import dstep.translator.Output;

class IncludeHandler
{
    private Options options;
    private string[string] submodules;
    private bool[string] includes;
    private bool[string] imports;
    private HeaderIndex headerIndex;
    immutable static string[string] knownIncludes;

    shared static this ()
    {
        knownIncludes = [
            "complex" : "core.stdc.complex",
            "config" : "core.stdc.config",
            "ctype" : "core.stdc.ctype",
            "errno" : "core.stdc.errno",
            "fenv" : "core.stdc.fenv",
            "float" : "core.stdc.float",
            "inttypes" : "core.stdc.inttypes",
            "limits" : "core.stdc.limits",
            "locale" : "core.stdc.locale",
            "math" : "core.stdc.math",
            "signal" : "core.stdc.signal",
            "stdarg" : "core.stdc.stdarg",
            "stddef" : "core.stdc.stddef",
            "stdint" : "core.stdc.stdint",
            "_int8_t" : "core.stdc.stdint",
            "_int16_t" : "core.stdc.stdint",
            "_int32_t" : "core.stdc.stdint",
            "_int64_t" : "core.stdc.stdint",
            "_uint8_t" : "core.stdc.stdint",
            "_uint16_t" : "core.stdc.stdint",
            "_uint32_t" : "core.stdc.stdint",
            "_uint64_t" : "core.stdc.stdint",
            "stdio" : "core.stdc.stdio",
            "corecrt_wstdio" : "core.stdc.stdio",
            "stdlib" : "core.stdc.stdlib",
            "string" : "core.stdc.string",
            "tgmath" : "core.stdc.tgmath",
            "time" : "core.stdc.time",
            "_time_t" : "core.stdc.time",
            "corecrt" : "core.stdc.time",
            "crtdefs" : "core.stdc.time",
            "wchar" : "core.stdc.wchar_",
            "wctype" : "core.stdc.wctype",

            "dirent" : "core.sys.posix.dirent",
            "dlfcn" : "core.sys.posix.dlfcn",
            "fcntl" : "core.sys.posix.fcntl",
            "netdb" : "core.sys.posix.netdb",
            "poll" : "core.sys.posix.poll",
            "pthread" : "core.sys.posix.pthread",
            "pwd" : "core.sys.posix.pwd",
            "sched" : "core.sys.posix.sched",
            "semaphore" : "core.sys.posix.semaphore",
            "setjmp" : "core.sys.posix.setjmp",
            "signal" : "core.sys.posix.signal",
            "termios" : "core.sys.posix.termios",
            "ucontext" : "core.sys.posix.ucontext",
            "unistd" : "core.sys.posix.unistd",
            "utime" : "core.sys.posix.utime",

            "arpa/inet" : "core.sys.posix.arpa.inet",

            "net/if" : "core.sys.posix.net.if_",

            "netinet/in" : "core.sys.posix.netinet.in_",
            "netinet/tcp" : "core.sys.posix.netinet.tcp",

            "sys/ipc" : "core.sys.posix.sys.ipc",
            "sys/mman" : "core.sys.posix.sys.mman",
            "sys/select" : "core.sys.posix.sys.select",
            "sys/shm" : "core.sys.posix.sys.shm",
            "sys/socket" : "core.sys.posix.sys.socket",
            "sys/stat" : "core.sys.posix.sys.stat",
            "sys/time" : "core.sys.posix.sys.time",
            "_time_t" : "core.stdc.time",
            "sys/types" : "core.sys.posix.sys.types",
            "sys/_types" : "core.sys.posix.sys.types",
            "sys/uio" : "core.sys.posix.sys.uio",
            "sys/un" : "core.sys.posix.sys.un",
            "sys/utsname" : "core.sys.posix.sys.utsname",
            "sys/wait" : "core.sys.posix.sys.wait",

            "windows" : "core.sys.windows.windows"
        ];
    }

    this (HeaderIndex headerIndex, Options options)
    {
        import std.format;
        import std.algorithm : filter;

        this.headerIndex = headerIndex;
        this.options = options;

        if (options.packageName != "")
        {
            auto inputFiles = options.inputFiles.filter!(
                x => x != options.inputFile);

            foreach (file; inputFiles)
            {
                auto packageName = options.packageName;
                auto normalize = options.normalizeModules;
                submodules[file] = fullModuleName(packageName, file, normalize);
            }
        }
    }

    void addInclude (string include)
    {
        import std.path;
        import std.file;
        import std.array;

        auto absolute = include.asAbsNormPath;

        if (absolute != options.inputFile && !include.empty)
        {
            if (exists(absolute) && isFile(absolute))
                includes[absolute] = true;
            else
                includes[include] = true;
        }
    }

    void addImport (string imp)
    {
        imports[imp] = true;
    }

    void addCompatible ()
    {
        includes["config.h"] = true;
    }

    void toImports (Output output)
    {
        import std.algorithm : map;
        import std.array : array;
        import std.format : format;
        import std.algorithm.iteration : filter, map;

        Set!string standard, package_, unhandled;

        foreach (entry; includes.byKey)
        {
            if (auto i = isKnownInclude(entry))
                standard.add(toImport(i));
            else if (auto i = isPackageSubmodule(entry))
                package_.add(toSubmoduleImport(i));
            else
                unhandled.add(format(`/+ #include "%s" +/`, entry));
        }

        auto extra = imports.byKey.map!(e => toImport(e)).array;

        importsBlock(output, standard.keys);
        importsBlock(output, extra.array);
        importsBlock(output, package_.keys);

        if (options.keepUntranslatable)
            importsBlock(output, unhandled.keys);

        output.finalize();
    }

    void resolveDependency(in Cursor cursor)
    {
        auto module_ = headerIndex.searchKnownModules(cursor);

        if (module_ !is null)
            addImport(module_);
    }

private:

    void importsBlock(Output output, string[] imports)
    {
        import std.array : empty;
        import std.algorithm : sort, filter;

        foreach (entry; imports.sort().filter!(e => !e.empty))
            output.singleLine(entry);

        if (!output.empty)
            output.separator();
    }

    string toImport (string str)
    {
        return "import " ~ str ~ ";";
    }

    string toSubmoduleImport (string str)
    {
        if (options.publicSubmodules)
            return "public import " ~ str ~ ";";
        else
            return "import " ~ str ~ ";";
    }

    string isKnownInclude (string include)
    {
        import std.path : stripExtension, baseName;

        include = stripExtension(baseName(include));

        if (auto ptr = include in knownIncludes)
            return *ptr;
        else
            return null;
    }

    string isPackageSubmodule (string include)
    {
        if (auto ptr = include in submodules)
            return *ptr;
        else
            return null;
    }
}
