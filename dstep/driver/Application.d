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
	}
	
	override void run ()
	{
		handleArguments;
		startConversion;
	}

private:
	
	void startConversion ()
	{
		index = Index(false, false);
		translationUnit = TranslationUnit.parse(index, inputFiles.first, args);
		
		if (!translationUnit.isValid)
			throw new DStepException("An unknown error occurred");
		
		diagnostics = translationUnit.diagnostics;
		
		scope (exit)
			clean;
			
		if (handleDiagnostics)
		{
			auto translator = new Translator(inputFiles.first, translationUnit, output);
			translator.convert;
		}
	}
	
	bool anyErrors ()
	{
		return diagnostics.length > 0;
	}
	
	void handleArguments ()
	{
		getopt(args, std.getopt.config.caseSensitive, std.getopt.config.passThrough, "o", &output);

        foreach (arg ; args[1 .. $])
            if (arg.first != '-')
                inputFiles ~= arg;

        args = args.remove(inputFiles);
	}
	
	bool handleDiagnostics ()
	{
	    bool convert = true;
	    	
		foreach (diag ; diagnostics)
		{
		    auto severity = diag.severity;
		    
		    with (CXDiagnosticSeverity)
		        if (convert)
	                convert = !(severity == CXDiagnostic_Error || severity == CXDiagnostic_Fatal);

	        writeln(stderr, diag.format);
		}

		return convert;
	}
	
	void clean ()
	{
		translationUnit.dispose;
		index.dispose;
	}
}