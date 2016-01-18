/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.driver.Application;

import std.getopt;
import std.stdio : writeln, stderr;
import Path = std.path : setExtension;

import DStack = dstack.application.Application;

import mambo.core._;
import mambo.util.Singleton;
import mambo.util.Use;

import clang.c.Index;

import clang.Compiler;
import clang.Index;
import clang.TranslationUnit;
import clang.Util;

import dstep.core.Exceptions;
import dstep.translator.Translator;
import dstep.translator.IncludeHandler;

class Application : DStack.Application
{
    mixin Singleton;

    enum Version = "0.2.2";

    private
    {
        string[] inputFiles;

        Index index;
        TranslationUnit translationUnit;
        DiagnosticVisitor diagnostics;

        Language language;
        string[] argsToRestore;
        bool helpFlag;
        Compiler compiler;
    }

    protected override void run ()
    {
        handleArguments;

        if (arguments.argument.input.hasValue)
        {
            inputFiles ~= arguments.argument.input;
            startConversion(inputFiles.first);
        }

        else
            startConversion("");
    }

    protected override void setupArguments ()
    {
        arguments.sloppy = true;
        arguments.passThrough = true;

        arguments.argument("input", "input files");

        arguments('o', "output", "Write output to")
            .params(1)
            .defaults(&defaultOutputFilename);

        arguments('x', "language", "Treat subsequent input files as having type <language>")
            .params(1)
            .restrict("c", "c-header", "objective-c", "objective-c-header")
            .on(&handleLanguage);

        arguments("objective-c", "Treat source input file as Objective-C input.");

        arguments('f',"import-filter", "A regex to filter includes that will be auto converted.")
            .params(1)
            .defaults(".*");

        arguments('p',"import-prefix", "A prefix to add to any custom generated import")
            .params(1)
            .defaults("");
    }

private:

    string defaultOutputFilename ()
    {
        return Path.setExtension(arguments.argument.input, "d");
    }

    void startConversion (string file)
    {
        if (arguments["objective-c"])
            argsToRestore ~= "-ObjC";

        index = Index(false, false);
        translationUnit = TranslationUnit.parse(index, file, compilerArgs,
            compiler.extraHeaders);

        // hope that the diagnostics below handle everything
        // if (!translationUnit.isValid)
        //     throw new DStepException("An unknown error occurred");

        diagnostics = translationUnit.diagnostics;

        scope (exit)
            clean;

        if (handleDiagnostics && file.any)
        {
            Translator.Options options;
            options.outputFile = arguments.output;
            options.language = language;

            auto translator = new Translator(file, translationUnit, options);
            translator.translate;
        }
    }

    void clean ()
    {
        translationUnit.dispose;
        index.dispose;
    }

    bool anyErrors ()
    {
        return diagnostics.length > 0;
    }

    void handleArguments ()
    {
        // FIXME: Cannot use type inference here, probably a bug. Results in segfault.
        if (arguments.rawArgs.any!((string e) => e == "-ObjC"))
            handleObjectiveC();

        if (arguments["import-prefix"].hasValue)
            handleAutoImportPrefix(arguments["import-prefix"].value);

        if (arguments["import-filter"].hasValue)
            handleAutoImportFilter(arguments["import-filter"].value);
    }

    void handleObjectiveC ()
    {
        argsToRestore ~= "-ObjC";
        language = Language.objC;
    }

    void handleLanguage (string language)
    {
        switch (language)
        {
            case "c":
            case "c-header":
                this.language = Language.c;
            break;

            // Can't handle C++ yet
            //
            // case "c++":
            // case "c++-header":
            //     this.language = Language.cpp;
            // break;

            case "objective-c":
            case "objective-c-header":
                this.language = Language.objC;
            break;

            default:
                throw new DStepException(`Unrecognized language "` ~ language ~ `"`);
        }

        argsToRestore ~= "-x";
        argsToRestore ~= language;
    }

    void handleAutoImportPrefix (string prefix)
    {
        includeHandler.autoImportPrefix = prefix;
    }

    void handleAutoImportFilter (string filter)
    {
        includeHandler.autoImportFilter = filter;
    }

    @property string[] remainingArgs ()
    {
        return arguments.rawArgs[1 .. $] ~ argsToRestore;
    }

    string[] extraArgs ()
    {
        return compiler.extraIncludePaths.map!(e => "-I" ~ e).toArray;
    }

    string[] compilerArgs ()
    {
        return remainingArgs ~ extraArgs;
    }

    bool handleDiagnostics ()
    {
        bool translate = true;

        foreach (diag ; diagnostics)
        {
            auto severity = diag.severity;

            with (CXDiagnosticSeverity)
                if (translate)
                    translate = !(severity == CXDiagnostic_Error || severity == CXDiagnostic_Fatal);

            writeln(stderr, diag.format);
        }

        return translate;
    }

    override protected void showHelp ()
    {
        helpFlag = true;

        println("Usage: dstep [options] <input>");
        println("Version: ", Version);
        println();
        println("Options:");
        println("    -o, --output <file>          Write output to <file>.");
        println("    -ObjC, --objective-c         Treat source input file as Objective-C input.");
        println("    -x, --language <language>    Treat subsequent input files as having type <language>.");
        println("    -h, --help                   Show this message and exit.");
        println("    -f, --import-filter          A regex to filter includes that will be auto converted to imports.");
        println("    -p, --import-prefix          A prefix to add to any import generated from an include.");
        println();
        println("All options that Clang accepts can be used as well.");
        println();
        println("Use the `-h' flag for help.");
    }
}
