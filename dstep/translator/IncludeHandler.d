/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jun 15, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.IncludeHandler;

import Path = std.path;
import std.regex;
import std.conv;

import mambo.core.Array;

private IncludeHandler includeHandler_;

@property IncludeHandler includeHandler ()
{
    return includeHandler_;
}

static this ()
{
    includeHandler_ = new IncludeHandler;
}

class IncludeHandler
{
    private string[] rawIncludes;
    private string[] imports;

    // True if includes should be converted to imports.
    private bool convertIncludes = false;

    // Includes matching this will be converted to imports.
    private Regex!char convertableIncludePattern = regex(".*");

    // Prefix for auto generated imports.
    private string importPrefix = "";

    static string[string] knownIncludes;

    static this ()
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
            "stdio" : "core.stdc.stdio",
            "stdlib" : "core.stdc.stdlib",
            "string" : "core.stdc.string",
            "tgmath" : "core.stdc.tgmath",
            "time" : "core.stdc.time",
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
            "sys/types" : "core.sys.posix.sys.types",
            "sys/_types" : "core.sys.posix.sys.types",
            "sys/uio" : "core.sys.posix.sys.uio",
            "sys/un" : "core.sys.posix.sys.un",
            "sys/utsname" : "core.sys.posix.sys.utsname",
            "sys/wait" : "core.sys.posix.sys.wait",

            "windows" : "core.sys.windows.windows"
        ];
    }

    void addInclude (string include)
    {
        rawIncludes ~= include;
    }

    void addImport (string imp)
    {
        imports ~= imp;
    }

    void addCompatible ()
    {
        imports ~= "core.stdc.config";
    }


    /// Makes includes that match regex filter be converted to import with prefix.
    @property void autoImportPrefix (string prefix)
    {
        convertIncludes = true;
        importPrefix = prefix;
    }

    @property string autoImportPrefix ()
    {
        return this.importPrefix;
    }

    /// Makes includes that match regex filter be converted to import with prefix.
    @property void autoImportFilter (string filter)
    {
        convertIncludes = true;
        convertableIncludePattern = regex(filter);
    }

    string[] toImports ()
    {
        auto r = rawIncludes.map!((e) {
            if (auto i = isKnownInclude(e))
                return toImport(i);
            else if (convertIncludes && isConvertableInclude(e) )
                return toImport(autoConvertInclude(e));
            else
                return "";
        });

        auto imps = imports.map!(e => toImport(e));

        return r.append(imps).filter!(e => e.any).unique.toArray;
    }

    /// Returns the base name (last component without extension) of a file path.
    static string bareName (string path)
    {
        return Path.stripExtension(Path.baseName(path));
    }

private:

    string toImport (string str)
    {
        return "import " ~ str ~ ";";
    }

    string isKnownInclude (string include)
    {
        include = Path.stripExtension(include);

        if (auto r = knownIncludes.find!((k, _) => include.endsWith(k)))
            return r.value;

        return null;
    }

    /// Checks if the given include file name should be converted to an import declaration.
    bool isConvertableInclude (string include)
    {
        // Do not try to convert empty strings, no matter what the pattern says.
        return include != "" && matchFirst(include, convertableIncludePattern);
    }


    /// Generates an importable module name from an include file name.
    string autoConvertInclude (string include)
    {
        string prefix = importPrefix;

        // If we have a prefix, append a dot to it if it doesn't already have one at the end.
        if (prefix != "" && !prefix.endsWith("."))
        {
            prefix ~= ".";
        }

        return prefix ~ bareName(include);
    }
}
