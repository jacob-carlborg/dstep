/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.driver.Application;

import std.getopt;
import std.stdio;

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
	
	enum Version = "0.0.0";
	
	private
	{
		string[] inputFiles;
		
		Index index;
		TranslationUnit translationUnit;
		DiagnosticVisitor diagnostics;
		
		string output = "foo.d";
		Language language;
		string[] argsToRestore;
	}
	
	override void run ()
	{
		handleArguments;
		startConversion(inputFiles.first);
	}

private:
	
	void startConversion (string file)
	{
		index = Index(false, false);
		translationUnit = TranslationUnit.parse(index, file, args[1 .. $]);
		
		if (!translationUnit.isValid)
			throw new DStepException("An unknown error occurred");
		
		diagnostics = translationUnit.diagnostics;
		
		scope (exit)
			clean;
			
		if (handleDiagnostics)
		{
			Translator.Options options;
			options.outputFile = output;
			options.language = language;

			auto translator = new Translator(file, translationUnit, options);
			translator.translate;
		}
	}
	
	bool anyErrors ()
	{
		return diagnostics.length > 0;
	}
	
	void handleArguments ()
	{
		getopt(args,
			std.getopt.config.caseSensitive,
			std.getopt.config.passThrough,
			"o", &output,
			"x", &handleLanguage);

		if (args.any!(e => e == "-ObjC"))
			handleObjectiveC();

		collectInputFiles();
		restoreArguments(argsToRestore);
	}
	
	void handleObjectiveC ()
	{
		language = Language.objectiveC;
		args = args.remove("-ObjC");
		println(args.indexOf("test_files/objc/classes.h"));
		argsToRestore ~= "-ObjC";
	}

	void handleLanguage (string option, string language)
	{
		switch (language)
		{
			case "c":
			case "c-header":
				this.language = Language.c;
			break;
		
			case "c++":
			case "c++-header":
				this.language = Language.cPlusPlus;
			break;
		
			case "objective-c":
			case "objective-c-header":
				this.language = Language.objectiveC;
			break;
		
			case "objective-c++":
			case "objective-c++-header":
				this.language = Language.objectiveCPlusPlus;
			break;
		
			default: // do nothing
		}

		argsToRestore ~= "-x";
		argsToRestore ~= language;
	}

	/**
	 * Restores the given arguments back into the list of argument passed to the application
	 * on the command line.
	 * 
	 * Use this method to restore arguments that were remove by std.getopt. This method is
	 * available since we want to handle some arguments ourself but also let Clang handle
	 * them.
	 */
	void restoreArguments (string[] args ...)
	{
		/*
		 * We're inserting the argument(s) at the beginning of the argument list to avoid
		 * being processed by std.getopt again, resulting in an infinite loop.
		 */
		this.args.insertInPlace(1, args);
	}

	void collectInputFiles ()
	{
		foreach (i, arg ; args[1 .. $])
			if (arg.first != '-' && args[i].first != '-')
                inputFiles ~= arg;

		if (inputFiles.isEmpty)
			throw new DStepException("No input files");

		args = args.remove(inputFiles);
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
	
	void clean ()
	{
		translationUnit.dispose;
		index.dispose;
	}
}