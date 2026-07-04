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
    private bool[string] includes;
    private bool[string] imports;
    private Set!string publicImports;
    private HeaderIndex headerIndex;

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

        const publicExtra = publicImports.byKey.map!(e => toImport(e, Visibility.public_)).array;
        auto extra = imports.byKey.map!(e => toImport(e)).array;

        importsBlock(output, standard.keys ~ publicExtra ~ extra.array);
        importsBlock(output, package_.keys);

        if (options.keepUntranslatable)
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
