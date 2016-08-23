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
    Language language = Language.c;
    string packageName;
    bool enableComments = true;
    bool publicSubmodules = false;
    bool keepUntranslatable = false;
    bool reduceAliases = true;
    bool portableWCharT = true;
    bool zeroParamIsVararg = false;
    bool singleLineFunctionHeaders = false;
    bool spaceAfterFunctionName = true;

    string toString() const
    {
        import std.format : format;

        return format(
            "Options(outputFile = %s, language = %s, enableComments = %s, "
            "reduceAliases = %s, portableWCharT = %s)",
            outputFile,
            language,
            enableComments,
            reduceAliases,
            portableWCharT);
    }
}

string fullModuleName(string packageName, string path)
{
    import std.path : baseName, stripExtension;
    import std.format : format;

    string moduleName = stripExtension(baseName(path));
    return format("%s.%s", packageName, moduleName);
}

