/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.driver.Application;

import std.getopt;
import std.stdio : writeln, stderr;

import DStack = dstack.application.Application;

import mambo.core._;
import mambo.util.Singleton;
import mambo.util.Use;

import clang.c.index;

import clang.Index;
import clang.TranslationUnit;

import dstep.core.Exceptions;
import dstep.translator.Translator;

class Application : DStack.Application
{
	mixin Singleton;
	
	enum Version = "0.0.1";
	
	private
	{
		string[] inputFiles;
		
		Index index;
		TranslationUnit translationUnit;
		DiagnosticVisitor diagnostics;

		Language language;
		string[] argsToRestore;
		bool helpFlag;
	}
	
	protected override void run ()
	{
		handleArguments;
		inputFiles ~= arguments.argument.input;
		startConversion(inputFiles.first);
	}

	protected override void setupArguments ()
	{
		arguments.sloppy = true;
		arguments.passThrough = true;

		arguments.argument("input", "input files");

		arguments('o', "output", "Write output to")
			.params(1)
			.defaults("foo.d");

		arguments('x', "Treat subsequent input files as having type")
			.params(1)
			.restrict("c", "c-header", "objective-c", "objective-c-header")
			.on(&handleLanguage);
	}

private:
	
	void startConversion (string file)
	{
		index = Index(false, false);
		translationUnit = TranslationUnit.parse(index, file, remainingArgs);
		
		if (!translationUnit.isValid)
			throw new DStepException("An unknown error occurred");
		
		diagnostics = translationUnit.diagnostics;
		
		scope (exit)
			clean;
			
		if (handleDiagnostics)
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
		if (arguments.args.any!(e => e == "-ObjC"))
			handleObjectiveC();
	}
	
	void handleObjectiveC ()
	{
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
			// 	this.language = Language.cpp;
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
		return arguments.args[1 .. $] ~ argsToRestore;
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

	void help ()
	{
		helpFlag = true;

		println("Usage: dstep [options] <input>");
		println("Version: ", Version);
		println();
		println("Options:");
		println("    -o, --output <file>    Write output to <file>.");
		println("    -ObjC                  Treat source input file as Objective-C input.");
		println("    -x <language>          Treat subsequent input files as having type <language>.");
		println("    -h, --help             Show this message and exit.");
		println();
		println("All options that Clang accepts can be used as well.");
		println();
		println("Use the `-h' flag for help.");
	}
}