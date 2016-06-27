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

import dstep.Configuration;
import dstep.translator.Options;
import dstep.core.Exceptions;
import dstep.translator.Options;
import dstep.translator.Translator;

class Application
{
    enum Version = "0.2.2";

    private
    {
        Configuration config;
    }

    public this (Configuration config)
    {
        this.config = config;
    }

    public void run ()
    {
        import std.exception : enforce;

        enforce!DStepException(config.inputFiles.length > 0,
            "Must supply at least one input file");

        // when only one input file is supplied, -o argument is
        // interpreted as file path, otherwise as base directory path
        bool singleFileInput = config.inputFiles.length == 1;

        // parallel generation of D modules for each of input files
        foreach (fileName; config.inputFiles)
        {
            string outputFilename;

            if (singleFileInput)
            {
                if (config.output.length)
                    outputFilename = config.output;
                else
                    outputFilename = defaultOutputFilename(fileName, false);
            }
            else
            {
                outputFilename = Path.buildPath(config.output,
                    defaultOutputFilename(fileName, false));
            }

            string outputDir = Path.dirName(outputFilename);
            if (!exists(outputDir))
                mkdirRecurse(outputDir);

            auto conversionTask = task!startParsingFile(config,
                fileName, outputFilename);

            conversionTask.executeInNewThread();
        }
    }

    static void startParsingFile (const Configuration config, string fileName,
        string outputFilename)
    {
        ParseFile(config, fileName, outputFilename)
            .startConversion();
    }

    static string defaultOutputFilename (string inputFile, bool useBaseName = true)
    {
        if (useBaseName)
            return Path.setExtension(Path.baseName(inputFile), "d");

        return Path.setExtension(inputFile, "d");
    }
}

private struct ParseFile
{
    private
    {
        string inputFile;
        string outputFile;
        Index index;
        TranslationUnit translationUnit;
        DiagnosticVisitor diagnostics;

        const Configuration config;
        Compiler compiler;
    }

    this (
        const Configuration config,
        string inputFile,
        string outputFile)
    {
        this.config = config;
        this.inputFile = inputFile;
        this.outputFile = outputFile;
    }

    void startConversion ()
    {
        index = Index(false, false);
        translationUnit = TranslationUnit.parse(
            index,
            inputFile,
            config.clangParams,
            compiler.extraHeaders);

        // hope that the diagnostics below handle everything
        // if (!translationUnit.isValid)
        //     throw new DStepException("An unknown error occurred");

        diagnostics = translationUnit.diagnostics;

        if (handleDiagnostics && exists(inputFile))
        {
            import std.array : array;

            Options options;
            options.inputFiles = config.inputFiles.map!(path => path.asAbsNormPath).array;
            options.inputFile = inputFile.asAbsNormPath;
            options.outputFile = outputFile.asAbsNormPath;
            options.language = config.language;
            options.enableComments = !config.noComments;
            options.packageName = config.packageName;
            options.publicSubmodules = config.publicSubmodules;
            options.reduceAliases = !config.dontReduceAliases;

            auto translator = new Translator(translationUnit, options);
            translator.translate;
        }
    }

    ~this ()
    {
        clean();
    }

private:

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
