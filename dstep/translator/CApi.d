/**
 * Copyright: Copyright (c) 2013 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jul 16, 2013
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.CApi;

import mambo.core.string;

import clang.c.index;

import clang.Index;
import clang.TranslationUnit;

import core.stdc.string;
import dstep.translator.Translator;
alias DTranslator = dstep.translator.Translator.Translator;

struct TranslationArgs
{
	const char* file;
	const char* outputFile;
	const char** args;
	size_t argsLenght;
	Language language;

private:

	DTranslationArgs toTranslationArgs ()
	{
		DTranslationArgs args;

		args.file = file.toString();
		args.outputFile = outputFile.toString();
		args.args = toDArray();
		args.language = language;

		return args;
	}

	string[] toDArray ()
	{
		string[] arr;
		arr.reserve(argsLenght);

		foreach (i ; 0 .. argsLenght)
			arr ~= args[i].toString();

		return arr;
	}
}

extern (C) int dstep_translate (TranslationArgs args, out Translator translator)
{
	return translate(args.toTranslationArgs(), translator);
}

extern (C) void dstep_disposeTranslator (Translator translator)
{
	translator.dispose();
}

extern (C) bool dstep_shouldDisposeTranslator (Translator translator)
{
	return translator.shouldDispose();
}

struct Translator
{
	CXIndex index;
	CXTranslationUnit translationUnit;

private:

	void dispose ()
	{
		auto idx = Index(index);
		auto transUnit = TranslationUnit(translationUnit);

		if (idx.isValid)
			Index(idx).dispose();

		if (transUnit.isValid)
			transUnit.dispose();
	}

	@property bool shouldDispose ()
	{
		return Index(index).isValid || TranslationUnit(translationUnit).isValid;
	}
}

private:

struct DTranslationArgs
{
	string file;
	string outputFile;
	string[] args;
	Language language;
}

int translate (DTranslationArgs args, out Translator translator)
{
	int result = 0;

	auto index = Index(false, false);
	auto translationUnit = TranslationUnit.parse(index, args.file, args.args);

	if (!translationUnit.isValid)
	{
		result = 1;
		//throw new DStepException("An unknown error occurred");
	}

	auto diagnostics = translationUnit.diagnostics;

	scope (exit)
	{
		if (result != 0)
		{
			translationUnit.dispose();
			index.dispose();
		}
	}

	if (diagnostics.any)
	{
		translator = Translator(index, translationUnit);
		result = 1;
	}

	else
	{
		DTranslator.Options options;
		options.outputFile = args.outputFile;
		options.language = args.language;

		auto dtrans = new DTranslator(args.file, translationUnit, options);
		dtrans.translate();
	}

	return result;
}