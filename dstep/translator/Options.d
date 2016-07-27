/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: May 21, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Options;

enum Language
{
    c,
    objC
}

struct Options
{
    string[] inputFiles;
    string inputFile;
    string outputFile;
    string packageName;
    Language language = Language.c;
    bool enableComments = true;
    bool publicSubmodules = false;
    bool keepUntranslatable = false;
}

string fullModuleName(string packageName, string path)
{
    import std.path : baseName, stripExtension;
    import std.format : format;

    string moduleName = stripExtension(baseName(path));
    return format("%s.%s", packageName, moduleName);
}

