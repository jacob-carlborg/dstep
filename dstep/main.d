/**
 * Copyright: Copyright (c) 2016 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.main;

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
auto parseCLI (string[] args)
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
        "output|o", "Write output to", &config.output,
        "language|x", "Treat subsequent input files as having type <language>.", &parseLanguage,
        "objective-c", "Treat source input file as Objective-C input.", &forceObjectiveC,
        "no-comments", "Disable translation of comments.", &config.noComments,
        "public-submodules", "Use public imports for submodules.", &config.publicSubmodules,
        "package", "Specify package name.", &config.packageName,
        "dont-reduce-aliases", "Disable reduction of primitive type aliases.", &config.dontReduceAliases);

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

    if (config.clangParams.canFind("-ObjC"))
        config.language = Language.objC;

    return tuple(config, helpInformation);
}

unittest
{
    import std.meta : AliasSeq;

    Configuration config;
    GetoptResult getopResult;

    AliasSeq!(config, getopResult) = parseCLI(
        [ "dstep", "-Xpreprocessor", "-lsomething", "-x", "c-header", "file.h" ]);
    assert(config.language == Language.c);
    assert(config.inputFiles == [ "file.h" ]);
    assert(config.clangParams == [ "-x", "c-header", "-Xpreprocessor", "-lsomething" ]);
    assert(config.output == "");

    AliasSeq!(config, getopResult) = parseCLI(
        [ "dstep", "-ObjC", "file2.h", "--output=folder", "file.h" ]);
    assert(config.language == Language.objC);
    assert(config.inputFiles == [ "file2.h", "file.h" ]);
    assert(config.clangParams == [ "-ObjC" ]);
    assert(config.output == "folder");
}

version (unittest) { }
else:

/**
 *  Application entry point, handles CLI/config and forwards to
 *  dstep.driver.Application to do actual work.
 */
int main (string[] args)
{
    auto parseResult = parseCLI(args);
    Configuration config = parseResult[0];
    GetoptResult getoptResult = parseResult[1];

    if (getoptResult.helpWanted)
    {
        showHelp(config, getoptResult);
        return 0;
    }

    import dstep.driver.Application;
    import std.stdio;

    auto application = new Application(config);

    try
    {
        application.run();
    }
    catch (DStepException e)
    {
        writeln("An error occurred: ", e);
        return -1;
    }
    catch (Throwable e)
    {
        writeln("An unknown error occurred: ", e);
        throw e;
    }

    return 0;
}

void showHelp (Configuration config, GetoptResult)
{
    import std.stdio;
    import std.string;

    writeln("Usage: dstep [options] <input>");
    writeln("Version: ", strip(config.Version));
    writeln();
    writeln("Options:");
    writeln("    -o, --output <file>          Write output to <file>.");
    writeln("    -o, --output <directory>     Write all the files to <directory>, in case of multiple input files.");
    writeln("    -ObjC, --objective-c         Treat source input file as Objective-C input.");
    writeln("    -x, --language <language>    Treat subsequent input files as having type <language>.");
    writeln("    -h, --help                   Show this message and exit.");
    writeln("    --no-comments                Disable translation of comments.");
    writeln();
    writeln("All options that Clang accepts can be used as well.");
    writeln();
    writeln("Use the `-h' flag for help.");
}
