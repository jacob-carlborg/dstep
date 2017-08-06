/**
 * Copyright: Copyright (c) 2017 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.CommandLine;

import std.typecons : tuple, Tuple;
import std.getopt;

import dstep.Configuration;
import dstep.translator.Options;
import dstep.core.Exceptions;

/**
 *  Processes command-line arguments
 *
 *  Params:
 *      args = command-line arguments
 *
 *  Returns:
 *      2-element tuple with first element being aggregate struct of app
 *      configuration and second - getopt parse result
 */
auto parseCommandLine(string[] args)
{
    import std.getopt;

    Configuration config;

    // Parse dstep own paramaters:

    void parseLanguage (string param, string value)
    {
        config.clangParams ~= "-x";
        config.clangParams ~= value;

        switch (value)
        {
            case "c":
            case "c-header":
                config.language = Language.c;
                break;
            case "objective-c":
            case "objective-c-header":
                config.language = Language.objC;
                break;
            default:
                throw new DStepException(`Unrecognized language "` ~ value ~ `"`);
        }
    }

    bool forceObjectiveC;

    auto helpInformation = getopt(
        args,
        std.getopt.config.passThrough,
        std.getopt.config.caseSensitive,
        "output|o", &config.output,
        "objective-c", &forceObjectiveC,
        "language|x", &parseLanguage,
        makeGetOptArgs!config);

    // remove dstep binary name (args[0])
    args = args[1 .. $];

    // Seperate input files from clang paramaters:

    foreach (arg; args)
    {
        if (arg[0] == '-')
            config.clangParams ~= arg;
        else
            config.inputFiles ~= arg;
    }

    // Post-processing of CLI

    import std.algorithm : canFind;

    if (forceObjectiveC)
        config.clangParams ~= "-ObjC";

    if (config.clangParams.canFind("-ObjC"))
        config.language = Language.objC;

    return tuple(config, helpInformation);
}

unittest
{
    import std.algorithm.searching : find, empty;
    import std.meta : AliasSeq;

    Configuration config;
    GetoptResult getoptResult;

    AliasSeq!(config, getoptResult) = parseCommandLine(
        [ "dstep", "-Xpreprocessor", "-lsomething", "-x", "c-header", "file.h" ]);
    assert(config.language == Language.c);
    assert(config.inputFiles == [ "file.h" ]);
    assert(config.clangParams == [ "-x", "c-header", "-Xpreprocessor", "-lsomething" ]);
    assert(config.output == "");

    AliasSeq!(config, getoptResult) = parseCommandLine(
        [ "dstep", "-ObjC", "file2.h", "--output=folder", "file.h" ]);
    assert(config.language == Language.objC);
    assert(config.inputFiles == [ "file2.h", "file.h" ]);
    assert(config.clangParams == [ "-ObjC" ]);
    assert(config.output == "folder");

    AliasSeq!(config, getoptResult) = parseCommandLine(
        [ "dstep", "file.h", "--skip-definition", "foo" ]);
    assert(!config.skipDefinitions.find("foo").empty);

    AliasSeq!(config, getoptResult) = parseCommandLine(
        [ "dstep", "file.h", "--skip", "foo" ]);
    assert(!config.skipSymbols.find("foo").empty);

    AliasSeq!(config, getoptResult) = parseCommandLine(
        [ "dstep", "file.h", "--skip", "foo", "--skip-definition", "bar" ]);
    assert(!config.skipDefinitions.find("bar").empty);
    assert(!config.skipSymbols.find("foo").empty);
}
