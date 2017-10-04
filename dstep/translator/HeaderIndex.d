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

    private size_t[string] headers_;
    private string[size_t] reverse_;
    private Set!(Tuple!(size_t, size_t)) directInclusions;
    private Set!(Tuple!(size_t, size_t)) indirectInclusions;
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

                auto pair = tuple(headers_[includedPath], headers_[path]);
                directInclusions.add(pair);
            }
        }

        foreach (header, closure; transitiveClosure())
        {
            foreach (closureHeader; closure)
                indirectInclusions.add(tuple(header, closureHeader));
        }
    }

    auto headers()
    {
        return headers_.byKey();
    }

    bool isIncludedBy(string header, string by)
    {
        return directInclusions.contains(
            tuple(headers_[header.asAbsNormPath], headers_[by.asAbsNormPath]));
    }

    bool isReachableBy(string header, string by)
    {
        return indirectInclusions.contains(
            tuple(headers_[header.asAbsNormPath], headers_[by.asAbsNormPath]));
    }

    bool isReachableThrough(string header, string via, string by)
    {
        return isReachableBy(header, via) && isReachableBy(via, by);
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
            includedBy[inclusion[0]] ~= inclusion[1];


        void visit(size_t header)
        {
            if (statuses[header] == Status.visited)
                return;

            if (statuses[header] == Status.visiting)
                throw new Exception("The include graph isn't a DAG.");

            statuses[header] = Status.visiting;

            foreach (includingHeader; includedBy[header])
                visit(includingHeader);

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
            includedTo[inclusion[1]] ~= inclusion[0];

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
    private string mainFilePath;

    public this(TranslationUnit translationUnit)
    {
        import std.algorithm;

        auto directives = translationUnit.cursor.children
            .filter!(cursor => cursor.kind == CXCursorKind.inclusionDirective);

        includeGraph_ = new IncludeGraph(directives);
        mainFilePath = translationUnit.spelling.asAbsNormPath;
        this(directives);
    }

    private this(T)(T directives)
    {
        import std.random;
        import std.range;

        stdLibPaths = resolveStdLibPaths(directives);
    }

    bool isFromStdLib(string path, string header)
    {
        auto headerPath = header in stdLibPaths;

        if (headerPath is null)
            return false;

        return includeGraph.isReachableThrough(
            path.asAbsNormPath,
            *headerPath,
            mainFilePath);
    }

    bool isFromStdLib(Cursor cursor, string header)
    {
        return isFromStdLib(cursor.file.name, header);
    }

    IncludeGraph includeGraph()
    {
        return includeGraph_;
    }

    private string[string] resolveStdLibPaths(T)(T directives) const
    {
        immutable uint[string] stdlib = [
            "assert.h" : 89,
            "ctype.h" : 89,
            "errno.h" : 89,
            "float.h" : 89,
            "limits.h" : 89,
            "locale.h" : 89,
            "math.h" : 89,
            "setjmp.h" : 89,
            "signal.h" : 89,
            "stdarg.h" : 89,
            "stddef.h" : 89,
            "stdio.h" : 89,
            "stdlib.h" : 89,
            "string.h" : 89,
            "time.h" : 89,
            "iso646.h" : 95,
            "wctype.h" : 95,
            "wchar.h" : 95,
            "complex.h" : 99,
            "fenv.h" : 99,
            "inttypes.h" : 99,
            "tgmath.h" : 99,
            "stdint.h" : 99,
            "stdbool.h" : 99,
            "stdnoreturn.h" : 11,
            "threads.h" : 11,
            "uchar.h" : 11,
            "stdatomic.h" : 11,
            "stdalign.h" : 11
        ];

        string[string] paths;

        foreach (directive; directives)
        {
            auto release = directive.spelling in stdlib;

            if (release !is null && directive.tokens[1].spelling != "include_next")
            {
                auto absolutePath = directive.includedFile.absolutePath;
                paths[directive.spelling] = absolutePath;
            }
        }

        return paths;
    }
}
