/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.driver.Application;

import std.getopt;
import std.stdio : writeln, stderr;
import Path = std.path;
import std.file;
import std.parallelism;

import DStack = dstack.application.Application;

import mambo.arguments.Arguments;
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

class Application : DStack.Application
{
    mixin Singleton;

    enum Version = "0.2.2";

    private
    {
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
            auto inputFiles = arguments.argument.input.values[1 .. $];
            string outputDir = null;
            if (inputFiles.length > 0)
            {
                outputDir = arguments.output;
                if (arguments.output.any() && !exists(outputDir))
                    mkdirRecurse(outputDir);
            }

            foreach(string fileName; inputFiles)
            {
                auto conversionTask = task!startParsingFile(language, argsToRestore, fileName, true,
                                                            arguments, compiler, compilerArgs, outputDir);
                conversionTask.executeInNewThread();
            }

            startParsingFile(language, argsToRestore, arguments.argument.input.values[0], false, arguments,
                             compiler, compilerArgs, outputDir);
        }

        else
            startParsingFile(language, argsToRestore, "", false, arguments, compiler, compilerArgs, null);
    }

    protected override void setupArguments ()
    {
        arguments.sloppy = true;
        arguments.passThrough = true;

        arguments.argument("input", "input files").params(1, int.max);

        arguments('o', "output", "Write output to")
            .params(1)
            .defaults("");

        arguments('x', "language", "Treat subsequent input files as having type <language>")
            .params(1)
            .restrict("c", "c-header", "objective-c", "objective-c-header")
            .on(&handleLanguage);

        arguments("no-comments", "Disable translation of comments.");

        arguments("objective-c", "Treat source input file as Objective-C input.");
    }

    static void startParsingFile(Language lang, string[] argsToRestore, string fileName, bool createOutputFileName,
                                 Arguments args, Compiler comp, string[] compilerArguments, string outputDir)
    {
        auto parseFile = ParseFile(lang, argsToRestore, fileName, createOutputFileName,
                                   args, comp, compilerArguments, outputDir);
        parseFile.startConversion();
    }

private:

    void handleArguments ()
    {
        // FIXME: Cannot use type inference here, probably a bug. Results in segfault.
        if (arguments.rawArgs.any!((string e) => e == "-ObjC"))
            handleObjectiveC();
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

    struct ParseFile
    {
        private
        {
            string inputFile;
            string outputFile;
            string outputDirectory;
            Index index;
            TranslationUnit translationUnit;
            DiagnosticVisitor diagnostics;

            Language language;
            string[] argsToRestore;
            Compiler compiler;
            string[] compilerArgs;
            Arguments arguments;
        }

        this(
            Language language,
            string[] argsToRestore,
            string fileName,
            bool createOutputFileName,
            Arguments arguments,
            Compiler compiler,
            string[] compilerArgs,
            string outputDir)
        {
            this.language = language;
            this.argsToRestore = argsToRestore.dup;
            this.arguments = arguments;
            this.compiler = compiler;
            this.compilerArgs = compilerArgs.dup;

            inputFile = fileName;

            if (outputDir != null)
                outputFile = Path.buildPath(outputDir, defaultOutputFilename(false));
            else if (!createOutputFileName && arguments.output != "")
                outputFile = arguments.output;
            else
                outputFile = defaultOutputFilename();

            outputDir = Path.dirName(outputFile);
            if (!exists(outputDir))
                mkdirRecurse(outputDir);
        }

        void startConversion ()
        {
            if (arguments["objective-c"])
                argsToRestore ~= "-ObjC";
            index = Index(false, false);
            translationUnit = TranslationUnit.parse(
                index,
                inputFile,
                compilerArgs,
                compiler.extraHeaders);

            // hope that the diagnostics below handle everything
            // if (!translationUnit.isValid)
            //     throw new DStepException("An unknown error occurred");

            diagnostics = translationUnit.diagnostics;

            if (handleDiagnostics && exists(inputFile))
            {
                Options options;
                options.outputFile = outputFile;
                options.language = language;
                options.enableComments = !arguments["no-comments"];

                auto translator = new Translator(translationUnit, options);

                translator.translate;
            }
        }

        ~this()
        {
            clean();
        }

    private:

        string defaultOutputFilename (bool useBaseName = true)
        {
            if (useBaseName)
                return Path.setExtension(Path.baseName(inputFile), "d");
            return Path.setExtension(inputFile, "d");
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
    }

    override protected void showHelp ()
    {
        helpFlag = true;

        println("Usage: dstep [options] <input>");
        println("Version: ", Version);
        println();
        println("Options:");
        println("    -o, --output <file>          Write output to <file>.");
        println("    -o, --output <directory>     Write all the files to <directory>, in case of multiple input files.");
        println("    -ObjC, --objective-c         Treat source input file as Objective-C input.");
        println("    -x, --language <language>    Treat subsequent input files as having type <language>.");
        println("    -h, --help                   Show this message and exit.");
        println("    --no-comments                Disable translation of comments.");
        println();
        println("All options that Clang accepts can be used as well.");
        println();
        println("Use the `-h' flag for help.");
    }
}
