/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: May 21, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Options;

import clang.Util;

import dstep.translator.ConvertCase;

enum Language
{
    c,
    objC
}

enum CollisionAction
{
    ignore,
    rename,
    abort
}

struct Options
{
    import clang.Cursor: Cursor;

    string[] inputFiles;
    string inputFile;
    string outputFile;
    Language language = Language.c;
    string packageName;
    bool enableComments = true;
    bool publicSubmodules = false;
    bool normalizeModules = false;
    bool keepUntranslatable = false;
    bool reduceAliases = true;
    bool translateMacros = true;
    bool portableWCharT = true;
    bool zeroParamIsVararg = false;
    bool singleLineFunctionSignatures = false;
    bool spaceAfterFunctionName = true;
    bool aliasEnumMembers = false;
    bool renameEnumMembers = false;
    Set!string skipDefinitions;
    Set!string skipSymbols;
    bool printDiagnostics = true;
    CollisionAction collisionAction = CollisionAction.rename;
    const(string)[] globalAttributes;
    const(string)[] globalImports;
    const(string)[] publicGlobalImports;
    bool delegate(ref const(Cursor)) isWantedCursorForTypedefs;

    string toString() const
    {
        import std.format : format;

        return format(
            "Options(outputFile = %s, language = %s, enableComments = %s, " ~
            "reduceAliases = %s, portableWCharT = %s)",
            outputFile,
            language,
            enableComments,
            reduceAliases,
            portableWCharT);
    }
}

string fullModuleName(string packageName, string path, bool normalize = true)
{
    import std.algorithm;
    import std.path : baseName, stripExtension;
    import std.range;
    import std.uni;
    import std.utf;

    dchar replace(dchar c)
    {
        if (c == '_' || c.isWhite)
            return '_';
        else if (c.isPunctuation)
            return '.';
        else
            return c;
    }

    bool discard(dchar c)
    {
        return c.isAlphaNum || c == '_' || c == '.';
    }

    bool equivalent(dchar a, dchar b)
    {
        return (a == '.' || a == '_') && (b == '.' || b == '_');
    }

    auto moduleBaseName = stripExtension(baseName(path));
    auto moduleName = moduleBaseName.map!replace.filter!discard.uniq!equivalent;


    if (normalize)
    {
        auto segments = moduleName.split!(x => x == '.');
        auto normalized = segments.map!(x => x.toUTF8.toSnakeCase).join('.');
        return only(packageName, normalized).join('.');
    }
    else
    {
        return only(packageName, moduleName.toUTF8).join('.');
    }
}

unittest
{
    assert(fullModuleName("pkg", "foo") == "pkg.foo");
    assert(fullModuleName("pkg", "Foo") == "pkg.foo");
    assert(fullModuleName("pkg", "Foo.ext") == "pkg.foo");

    assert(fullModuleName("pkg", "Foo-bar.ext") == "pkg.foo.bar");
    assert(fullModuleName("pkg", "Foo_bar.ext") == "pkg.foo_bar");
    assert(fullModuleName("pkg", "Foo@bar.ext") == "pkg.foo.bar");
    assert(fullModuleName("pkg", "Foo~bar.ext") == "pkg.foo.bar");
    assert(fullModuleName("pkg", "Foo bar.ext") == "pkg.foo_bar");

    assert(fullModuleName("pkg", "Foo__bar.ext") == "pkg.foo_bar");
    assert(fullModuleName("pkg", "Foo..bar.ext") == "pkg.foo.bar");
    assert(fullModuleName("pkg", "Foo#$%#$%#bar.ext") == "pkg.foo.bar");
    assert(fullModuleName("pkg", "Foo_#$%#$%#bar.ext") == "pkg.foo_bar");

    assert(fullModuleName("pkg", "FooBarBaz.ext") == "pkg.foo_bar_baz");
    assert(fullModuleName("pkg", "FooBar.BazQux.ext") == "pkg.foo_bar.baz_qux");

    assert(fullModuleName("pkg", "FooBarBaz.ext", false) == "pkg.FooBarBaz");
    assert(fullModuleName("pkg", "FooBar.BazQux.ext", false) == "pkg.FooBar.BazQux");
}
