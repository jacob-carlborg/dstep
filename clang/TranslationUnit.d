/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 1, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.TranslationUnit;

import std.string;

import mambo.core.io;

import clang.c.Index;
import clang.Cursor;
import clang.Diagnostic;
import clang.File;
import clang.Index;
import clang.Util;
import clang.Visitor;

struct TranslationUnit
{
    mixin CX;

    static TranslationUnit parse (Index index, string sourceFilename, string[] commandLineArgs,
        CXUnsavedFile[] unsavedFiles = null,
        uint options = CXTranslationUnit_Flags.CXTranslationUnit_DetailedPreprocessingRecord)
    {
        return TranslationUnit(
            clang_parseTranslationUnit(
                index.cx,
                sourceFilename.toStringz,
                strToCArray(commandLineArgs),
                cast(int) commandLineArgs.length,
                toCArray!(CXUnsavedFile)(unsavedFiles),
                cast(uint) unsavedFiles.length,
                options));
    }

    static TranslationUnit parseString (
        Index index,
        string source,
        string[] commandLineArgs,
        CXUnsavedFile[] unsavedFiles = null,
        uint options = CXTranslationUnit_Flags.CXTranslationUnit_DetailedPreprocessingRecord)
    {
        import std.file;

        auto file = namedTempFile("dstep", ".h");
        auto name = file.name();
        file.write(source);
        file.flush();
        file.detach();

        auto translationUnit = TranslationUnit.parse(
            index,
            name,
            commandLineArgs,
            unsavedFiles,
            options);

        remove(name);

        return translationUnit;
    }

    private this (CXTranslationUnit cx)
    {
        this.cx = cx;
    }

    @property DiagnosticVisitor diagnostics ()
    {
        return DiagnosticVisitor(cx);
    }

    @property DeclarationVisitor declarations ()
    {
        return DeclarationVisitor(clang_getTranslationUnitCursor(cx));
    }

    File file (string filename)
    {
        return File(clang_getFile(cx, filename.toStringz));
    }

    @property Cursor cursor ()
    {
        auto r = clang_getTranslationUnitCursor(cx);
        return Cursor(r);
    }
}

struct DiagnosticVisitor
{
    private CXTranslationUnit translatoinUnit;

    this (CXTranslationUnit translatoinUnit)
    {
        this.translatoinUnit = translatoinUnit;
    }

    size_t length ()
    {
        return clang_getNumDiagnostics(translatoinUnit);
    }

    int opApply (int delegate (ref Diagnostic) dg)
    {
        int result;

        foreach (i ; 0 .. length)
        {
            auto diag = clang_getDiagnostic(translatoinUnit, cast(uint) i);
            auto dDiag = Diagnostic(diag);
            result = dg(dDiag);

            if (result)
                break;
        }

        return result;
    }
}
