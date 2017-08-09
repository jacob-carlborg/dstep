/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jan 21, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

module dstep.translator.HeaderIndex;

import clang.c.Index;
import clang.Cursor;
import clang.Index;
import clang.Util;
import clang.TranslationUnit;

class IncludeGraph
{
    import std.typecons;

    struct Inclusion
    {
        size_t included;
        size_t including;
    }

    private size_t[string] headers_;
    private string[size_t] reverse_;
    private Set!Inclusion directInclusions;
    private Set!Inclusion indirectInclusions;
    private string internalPrefix;

    public this(TranslationUnit translationUnit)
    {
        import std.algorithm;

        auto directives = translationUnit.cursor.children
            .filter!(cursor => cursor.kind == CXCursorKind.inclusionDirective);

        this(directives);
    }

    public this(T)(T directives)
    {
        import std.random;
        import std.range;

        internalPrefix = generate(() => uniform!("[]")('a', 'z'))
            .take(32).array.idup;

        foreach (directive; directives)
        {
            auto path = directive.file.absolutePath;
            auto includedPath = directive.includedFile.absolutePath;

            if (path != "" && includedPath != "")
            {
                if (path !in headers_)
                {
                    reverse_[headers_.length] = path;
                    headers_[path] = headers_.length;
                }

                if (includedPath !in headers_)
                {
                    reverse_[headers_.length] = includedPath;
                    headers_[includedPath] = headers_.length;
                }

                auto pair = Inclusion(headers_[includedPath], headers_[path]);
                directInclusions.add(pair);
            }
        }

        removeCycles(directInclusions);

        foreach (header, closure; transitiveClosure())
        {
            foreach (closureHeader; closure)
                indirectInclusions.add(Inclusion(header, closureHeader));
        }
    }

    auto headers()
    {
        return headers_.byKey();
    }

    bool isIncludedBy(string header, string by)
    {
        auto inclusion = Inclusion(
            headers_[header.asAbsNormPath],
            headers_[by.asAbsNormPath]);

        return directInclusions.contains(inclusion);
    }

    bool isReachableBy(string header, string by)
    {
        auto inclusion = Inclusion(
            headers_[header.asAbsNormPath],
            headers_[by.asAbsNormPath]);

        return indirectInclusions.contains(inclusion);
    }

    bool isReachableThrough(string header, string via, string by)
    {
        return isReachableBy(header, via) && isReachableBy(via, by);
    }

    void removeCycles(Set!Inclusion inclusions)
    {
        enum Status
        {
            pristine,
            visiting,
            visited
        }

        auto statuses = new Status[headers_.length];
        auto includedBy = new size_t[][headers_.length];

        foreach (inclusion; inclusions.byKey)
            includedBy[inclusion.included] ~= inclusion.including;

        void visit(size_t header, size_t includedHeader)
        {
            if (statuses[header] == Status.visited)
                return;

            if (statuses[header] == Status.visiting)
            {
                inclusions.remove(Inclusion(includedHeader, header));
            }
            else
            {
                statuses[header] = Status.visiting;
                foreach (includingHeader; includedBy[header])
                    visit(includingHeader, header);
                statuses[header] = Status.visited;
            }
        }

        foreach (header; headers_.byValue)
        {
            if (statuses[header] == Status.pristine)
                visit(header, size_t.max);
        }
    }

    private size_t[] topologicalSort()
    {
        import std.range;

        enum Status
        {
            pristine,
            visiting,
            visited
        }

        auto sorted = new size_t[0];
        auto statuses = new Status[headers_.length];
        auto includedBy = new size_t[][headers_.length];

        foreach (inclusion; directInclusions.byKey)
            includedBy[inclusion.included] ~= inclusion.including;

        void visit(size_t header)
        {
            if (statuses[header] == Status.visited)
                return;

            if (statuses[header] == Status.visiting)
                throw new Exception("The include graph isn't a DAG.");

            statuses[header] = Status.visiting;

            foreach (includedHeader; includedBy[header])
                visit(includedHeader);

            statuses[header] = Status.visited;
            sorted ~= header;
        }

        foreach (header; headers_.byValue)
        {
            if (statuses[header] == Status.pristine)
                visit(header);
        }

        return sorted;
    }

    private size_t[][] transitiveClosure()
    {
        import std.range;

        auto sorted = topologicalSort();
        auto closure = new size_t[][sorted.length];

        auto includedTo = new size_t[][headers_.length];

        foreach (inclusion; directInclusions.byKey)
            includedTo[inclusion.including] ~= inclusion.included;

        foreach (header; sorted)
        {
            closure[header] ~= header;

            foreach (transitiveHeader; closure[header])
            {
                foreach (includedHeader; includedTo[header])
                    closure[includedHeader] ~= transitiveHeader;
            }
        }

        return closure;
    }
}

class HeaderIndex
{
    private IncludeGraph includeGraph_;
    private string[string] stdLibPaths;
    private string[string] knownModules;
    private string mainFilePath;

    public this(TranslationUnit translationUnit)
    {
        immutable string[string] standardModuleMapping = [
            // standard c library
            "assert.h" : "core.stdc.assert_",
            "ctype.h" : "core.stdc.ctype",
            "errno.h" : "core.stdc.errno",
            "float.h" : "core.stdc.float_",
            "limits.h" : "core.stdc.limits",
            "locale.h" : "core.stdc.locale",
            "math.h" : "core.stdc.math",
            "signal.h" : "core.stdc.signal",
            "stdarg.h" : "core.stdc.stdarg",
            "stddef.h" : "core.stdc.stddef",
            "stdio.h" : "core.stdc.stdio",
            "stdlib.h" : "core.stdc.stdlib",
            "string.h" : "core.stdc.string",
            "time.h" : "core.stdc.time",
            "wctype.h" : "core.stdc.wctype",
            "wchar.h" : "core.stdc.wchar_",
            "complex.h" : "core.stdc.complex",
            "fenv.h" : "core.stdc.fenv",
            "inttypes.h" : "core.stdc.inttypes",
            "tgmath.h" : "core.stdc.tgmath",
            "stdint.h" : "core.stdc.stdint",
            // posix library
            "dirent.h" : "core.sys.posix.dirent",
            "dlfcn.h" : "core.sys.posix.dlfcn",
            "fcntl.h" : "core.sys.posix.fcntl",
            "netdb.h" : "core.sys.posix.netdb",
            "poll.h" : "core.sys.posix.poll",
            "pthread.h" : "core.sys.posix.pthread",
            "pwd.h" : "core.sys.posix.pwd",
            "sched.h" : "core.sys.posix.sched",
            "semaphore.h" : "core.sys.posix.semaphore",
            "setjmp.h" : "core.sys.posix.setjmp",
            "signal.h" : "core.sys.posix.signal",
            "termios.h" : "core.sys.posix.termios",
            "ucontext.h" : "core.sys.posix.ucontext",
            "unistd.h" : "core.sys.posix.unistd",
            "utime.h" : "core.sys.posix.utime",
            "arpa/inet.h" : "core.sys.posix.arpa.inet",
            "net/if.h" : "core.sys.posix.net.if_",
            "netinet/in.h" : "core.sys.posix.netinet.in_",
            "netinet/tcp.h" : "core.sys.posix.netinet.tcp",
            "sys/ipc.h" : "core.sys.posix.sys.ipc",
            "sys/mman.h" : "core.sys.posix.sys.mman",
            "sys/select.h" : "core.sys.posix.sys.select",
            "sys/shm.h" : "core.sys.posix.sys.shm",
            "sys/socket.h" : "core.sys.posix.sys.socket",
            "sys/stat.h" : "core.sys.posix.sys.stat",
            "sys/time.h" : "core.sys.posix.sys.time",
            "sys/types.h" : "core.sys.posix.sys.types",
            "sys/_types.h" : "core.sys.posix.sys.types",
            "sys/uio.h" : "core.sys.posix.sys.uio",
            "sys/un.h" : "core.sys.posix.sys.un",
            "sys/utsname.h" : "core.sys.posix.sys.utsname",
            "sys/wait.h" : "core.sys.posix.sys.wait",
            "sys/ioctl.h" : "core.sys.posix.sys.ioctl",
            // windows library
            "windows" : "core.sys.windows.windows"
        ];

        this (translationUnit, standardModuleMapping);
    }

    public this(
        TranslationUnit translationUnit,
        const string[string] moduleMapping)
    {
        import std.algorithm;

        if (!translationUnit.isCompiled())
        {
            throw new Exception(
                "The translation unit has to be compiled without errors.");
        }

        alias predicate =
            cursor => cursor.kind == CXCursorKind.inclusionDirective;

        auto directives = translationUnit.cursor.children.filter!predicate;

        includeGraph_ = new IncludeGraph(directives);
        mainFilePath = translationUnit.spelling.asAbsNormPath;
        this(directives, moduleMapping);
    }

    private this(T)(T directives, const string[string] moduleMapping)
    {
        knownModules = resolveKnownModules(
            directives,
            resolveKnownModulePaths(
                directives,
                moduleMapping));
    }

    string searchKnownModules(Cursor cursor)
    {
        auto knownModule = cursor.file.name.asAbsNormPath in knownModules;
        return knownModule !is null ? *knownModule : null;
    }

    IncludeGraph includeGraph()
    {
        return includeGraph_;
    }

    private struct KnownModule
    {
        string includePath;
        string moduleName;
    }

    private KnownModule[] resolveKnownModulePaths(T)(
        T directives,
        const string[string] moduleMapping) const
    {
        import std.algorithm;
        import std.array;

        Set!KnownModule knownModules;

        foreach (directive; directives)
        {
            auto moduleName = directive.spelling in moduleMapping;

            if (moduleName !is null)
            {
                auto absolutePath = directive.includedFile.absolutePath;
                knownModules.add(KnownModule(absolutePath, *moduleName));
            }
        }

        return knownModules.byKey.array;
    }

    private string[string] resolveKnownModules(T)(
        T directives,
        KnownModule[] moduleDescs)
    {
        string[string] knownModules;

        foreach (directive; directives)
        {
            auto absolutePath = directive.includedFile.absolutePath;

            foreach (desc; moduleDescs)
            {
                bool reachable = includeGraph.isReachableBy(
                    absolutePath,
                    desc.includePath);

                if (reachable)
                {
                    knownModules[absolutePath] = desc.moduleName;
                    break;
                }
            }
        }

        return knownModules;
    }
}
