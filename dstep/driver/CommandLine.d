/**
 * Copyright: Copyright (c) 2017 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.driver.CommandLine;

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
    import std.array : split;
    import std.getopt;

    Configuration config;

    // Parse dstep own parameters:

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

    auto splittedArgs = args.split("--");

    if (splittedArgs.length == 1)
        args = splittedArgs[0];
    else if (splittedArgs.length == 2)
    {
        args = splittedArgs[0];
        config.clangParams = splittedArgs[1];
    }

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

    // Separate input files from clang parameters:
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
    import std.algorithm.searching : find;
    import std.range.primitives : empty;
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

    AliasSeq!(config, getoptResult) = parseCommandLine(
        [ "dstep", "foo.h", "--", "-include", "bar.h" ]);
    assert(config.inputFiles == [ "foo.h" ]);
    assert(config.clangParams == [ "-include", "bar.h" ]);
}

/**
 *  "Real" application entry point, handles CLI/config and forwards to
 *  dstep.driver.Application to do actual work.
 *  Called by main.
 */
int run(string[] args)
{
    import std.stdio;
    import std.string;
    import clang.Util;

    auto parseResult = parseCommandLine(args);
    Configuration config = parseResult[0];
    GetoptResult getoptResult = parseResult[1];

    if (getoptResult.helpWanted || args.length == 1)
    {
        showHelp(config, getoptResult);
        return 0;
    }

    if (config.dstepVersion)
    {
        writeln(strip(config.Version));
        return 0;
    }

    if (config.clangVersion)
    {
        writeln(clangVersionString());
        return 0;
    }

    import dstep.driver.Application;

    auto application = new Application(config);

    try
    {
        application.run();
    }
    catch (DStepException e)
    {
        write(e.msg);
        return -1;
    }
    catch (Throwable e)
    {
        writeln("dstep: an unknown error occurred: ", e);
        throw e;
    }

    return 0;

}

void showHelp (Configuration config, GetoptResult getoptResult)
{
    import std.stdio;
    import std.string;
    import std.range;
    import std.algorithm;

    struct Entry
    {
        this(string option, string help)
        {
            this.option = option;
            this.help = help;
        }

        this(Option option)
        {
            if (option.optShort && option.optLong)
                this.option = format("%s, %s", option.optShort, option.optLong);
            else if (option.optShort)
                this.option = option.optShort;
            else
                this.option = option.optLong;

            auto pair = findSplitAfter(option.help, "!");

            if (!pair[0].empty)
            {
                this.option ~= pair[0][0 .. $ - 1];
                this.help = pair[1];
            }
            else
            {
                this.help = option.help;
            }
        }

        string option;
        string help;
    }

    auto customEntries = [
        Entry("-o, --output <file>", "Write output to <file>."),
        Entry("-o, --output <directory>", "Write all the files to <directory>, in case of multiple input files."),
        Entry("-ObjC, --objective-c", "Treat source input file as Objective-C input."),
        Entry("-x, --language", "Treat subsequent input files as having type <language>.")];

    auto generatedEntries = getoptResult.options
        .filter!(option => !option.help.empty)
        .map!(option => Entry(option));

    auto entries = chain(customEntries, generatedEntries);

    auto maxLength = entries.map!(entry => entry.option.length).array.reduce!max;

    auto helpString = appender!string();

    helpString.put("Usage: dstep [options] <input>\n");
    helpString.put(format("Version: %s\n\n", strip(config.Version)));
    helpString.put("Options:\n");

    foreach (entry; entries)
        helpString.put(format("    %-*s %s\n", cast(int) maxLength + 1, entry.option, entry.help));

    helpString.put(
        "\nAll options that Clang accepts can be used as well.\n" ~
        "Use the `-h' flag for help.");

    writeln(helpString.data);
}
