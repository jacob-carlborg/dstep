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

enum Visibility
{
    public_ = "public"
}

class IncludeHandler
{
    private Options options;
    private string[string] submodules;
    private string[string] includes;
    private bool[string] imports;
    private Set!string publicImports;
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
            "_stdio" : "core.stdc.stdio",
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
            "sys/ioctl" : "core.sys.posix.sys.ioctl",

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

    void addInclude (string name, string absolutePath)
    {
        assert(name.length > 0);
        assert(absolutePath.length > 0);

        includes.require(absolutePath, name);
    }

    void addInclude (string absolutePath)
    {
        import std.path : isAbsolute, baseName;
        import std.algorithm.searching : startsWith;

        auto includeName = headerIndex.getIncludeName(absolutePath);
        assert(includeName.length > 0);

        if (isAbsolute(includeName))
        {
            foreach (includePath; options.includePaths)
            {
                if (absolutePath.startsWith(includePath))
                {
                    includeName = absolutePath[includePath.length + 1 .. $];
                    break;
                }
            }


            if (isAbsolute(includeName))
                // didn't match any known path, fallback to just filename
                includeName = absolutePath.baseName;
        }

        addInclude(includeName, absolutePath);
    }

    void addImport (string imp)
    {
        imports[imp] = true;
    }

    void addImport (string imp, Visibility visibility)
    {
        final switch (visibility)
        {
            case Visibility.public_:
                publicImports.add(imp);
            break;
        }
    }

    void addCompatible ()
    {
        includes["config.h"] = "config.h";
    }

    void toImports (Output output)
    {
        import std.algorithm : map, sort, copy;
        import std.array : array, replace;
        import std.format : format;
        import std.algorithm.iteration : map, uniq;
        import std.path : stripExtension;
        import std.uni : toLower;

        Set!string standard, package_, unhandled;

        foreach (absolute, includeName; includes)
        {
            if (auto i = isPackageSubmodule(absolute))
                package_.add(toSubmoduleImport(i));
            else if (includeName.length > 0)
            {
                if (auto i = isKnownInclude(includeName))
                {
                    standard.add(toImport(i));
                }
                else
                {
                    auto name = stripExtension(includeName).toLower();
                    unhandled.add(format(`// FIXME: import %s;`, name.replace("/", ".")));
                }
            }
        }

        const publicExtra = publicImports.byKey.map!(e => toImport(e, Visibility.public_)).array;
        auto extra = imports.byKey.map!(e => toImport(e)).array;
        auto imports = standard.keys ~ publicExtra ~ extra.array;
        imports.sort();
        imports.length -= imports.uniq().copy(imports).length;

        importsBlock(output, imports);
        importsBlock(output, package_.keys);

        importsBlock(output, unhandled.keys);

        output.finalize();
    }

    bool resolveDependency(in Cursor cursor)
    {
        auto module_ = headerIndex.searchKnownModules(cursor);

        if (module_ !is null)
        {
            addImport(module_);
            return true;
        }

        return false;
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

    string toImport (string str, Visibility visibility)
    {
        return visibility ~ " " ~ toImport(str);
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
        import std.path : stripExtension;

        auto name = stripExtension(include);

        if (auto ptr = name in knownIncludes)
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
