/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.driver.Application;

import core.stdc.stdlib : EXIT_SUCCESS, EXIT_FAILURE;

import std.stdio;

import clang.Index;
import clang.TranslationUnit;

import dstep.core.io;
import dstep.core.Exceptions;
import dstep.converter.Converter;
import dstep.util.Singleton;
import dstep.util.Use;

class Application
{
	mixin Singleton;
	
	enum Version = "0.0.0";
	
	private
	{
		enum ExitCode
		{
			success = EXIT_SUCCESS,
			failure = EXIT_FAILURE
		}
		
		alias ExitCode delegate () Runnable;	
		
		string[] args;
		
		Index index;
		TranslationUnit translationUnit;
		DiagnosticVisitor diagnostics;
	}
	
	int run (string[] args)
	{
		this.args = args;
		
		return debugHandleExceptions in {
			startConversion;
			return ExitCode.success;
		};
	}

private:

	Use!(Runnable) handleExceptions ()
	{
		Use!(Runnable) use;
		
		use.args[0] = (Runnable dg) {
			try
				return dg();
			
			catch (DStepException e)
			{
				println("An error occurred: ", e);
				return ExitCode.failure;
			}
			
			catch (Exception e)
			{
				println("An unknown error occurred:");
				throw e;
			}
		};
		
		return use;
	}
	
	auto debugHandleExceptions ()
	{
		Use!(Runnable) use;
		use.args[0] = (Runnable dg) {
			return dg();
		};
		
		return use;
	}
	
	void startConversion ()
	{
		index = Index(false, false);
		translationUnit = TranslationUnit.parse(index, null, args);
		
		if (!translationUnit.isValid)
			throw new DStepException("An unknown error occurred");
		
		diagnostics = translationUnit.diagnostics;
		
		scope (exit)
			clean;

		if (anyErrors)
			handleDiagnostics;
			
		else
		{
			auto converter = new Converter(translationUnit);
			converter.convert;
		}
	}
	
	bool anyErrors ()
	{return false;
		return diagnostics.length > 0;
	}
	
	void handleDiagnostics ()
	{		
		foreach (diag ; diagnostics)
			writeln(stderr, diag.format);
	}
	
	void clean ()
	{
		translationUnit.dispose;
		index.dispose;
	}
}