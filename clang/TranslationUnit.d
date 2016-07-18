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
import clang.SourceLocation;
import clang.SourceRange;
import clang.Token;
import clang.Util;
import clang.Visitor;

struct TranslationUnit
{
    mixin CX;

    static TranslationUnit parse (
        Index index,
        string sourceFilename,
        const string[] commandLineArgs = ["-Wno-missing-declarations"],
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
        string[] commandLineArgs = ["-Wno-missing-declarations"],
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

    package this (CXTranslationUnit cx)
    {
        this.cx = cx;
    }

    @property DiagnosticVisitor diagnostics ()
    {
        return DiagnosticVisitor(cx);
    }

    @property DiagnosticSet diagnosticSet ()
    {
        return DiagnosticSet(clang_getDiagnosticSetFromTU(cx));
    }

    @property size_t numDiagnostics ()
    {
        return clang_getNumDiagnostics(cx);
    }

    @property DeclarationVisitor declarations ()
    {
        return DeclarationVisitor(clang_getTranslationUnitCursor(cx));
    }

    File file (string filename)
    {
        return File(clang_getFile(cx, filename.toStringz));
    }

    File file ()
    {
        return file(spelling);
    }

    @property string spelling ()
    {
        return toD(clang_getTranslationUnitSpelling(cx));
    }

    @property Cursor cursor ()
    {
        auto r = clang_getTranslationUnitCursor(cx);
        return Cursor(r);
    }

    SourceLocation location (uint offset)
    {
        CXFile file = clang_getFile(cx, spelling.toStringz);
        return SourceLocation(clang_getLocationForOffset(cx, file, offset));
    }

    SourceLocation location (string path, uint offset)
    {
        CXFile file = clang_getFile(cx, path.toStringz);
        return SourceLocation(clang_getLocationForOffset(cx, file, offset));
    }

    SourceRange extent (uint startOffset, uint endOffset)
    {
        CXFile file = clang_getFile(cx, spelling.toStringz);
        auto start = clang_getLocationForOffset(cx, file, startOffset);
        auto end = clang_getLocationForOffset(cx, file, endOffset);
        return SourceRange(clang_getRange(start, end));
    }

    package SourceLocation[] includeLocationsImpl(Range)(Range cursors)
    {
        // `cursors` range should at least contain all global
        // preprocessor cursors, although it can contain more.

        Set!string stacked;
        Set!string included;
        SourceLocation[] locationStack;
        SourceLocation[] locations = [ location("", 0), location(file.name, 0) ];

        foreach (cursor; cursors)
        {
            if (cursor.kind == CXCursorKind.CXCursor_InclusionDirective)
            {
                auto ptr = cursor.path in stacked;

                if (stacked.contains(cursor.path))
                {
                    while (locationStack[$ - 1].path != cursor.path)
                    {
                        stacked.remove(locationStack[$ - 1].path);
                        locations ~= locationStack[$ - 1];
                        locationStack = locationStack[0 .. $ - 1];
                    }

                    stacked.remove(cursor.path);
                    locations ~= locationStack[$ - 1];
                    locationStack = locationStack[0 .. $ - 1];
                }

                if ((cursor.includedPath in included) is null)
                {
                    locationStack ~= cursor.extent.end;
                    stacked.add(cursor.path);
                    locations ~= location(cursor.includedPath, 0);
                    included.add(cursor.includedPath);
                }
            }
        }

        while (locationStack.length != 0)
        {
            locations ~= locationStack[$ - 1];
            locationStack = locationStack[0 .. $ - 1];
        }

        return locations;
    }

    SourceLocation[] includeLocations()
    {
        return includeLocationsImpl(cursor.all);
    }

    package ulong delegate (SourceLocation)
        relativeLocationAccessorImpl(Range)(Range cursors)
    {
        // `cursors` range should at least contain all global
        // preprocessor cursors, although it can contain more.

        SourceLocation[] locations = includeLocationsImpl(cursors);

        struct Entry
        {
            uint index;
            SourceLocation location;

            int opCmp(ref const Entry s) const
            {
                return location.offset < s.location.offset ? -1 : 1;
            }

            int opCmp(ref const SourceLocation s) const
            {
                return location.offset < s.offset + 1 ? -1 : 1;
            }
        }

        Entry[][string] map;

        foreach (uint index, location; locations)
            map[location.path] ~= Entry(index, location);

        uint findIndex(SourceLocation a)
        {
            auto entries = map[a.path];

            import std.range;

            auto lower = assumeSorted(entries).lowerBound(a);

            return lower.empty ? 0 : lower.back.index;
        }

        ulong accessor(SourceLocation location)
        {
            return ((cast(ulong) findIndex(location)) << 32) |
                (cast(ulong) location.offset);
        }

        return &accessor;
    }

    size_t delegate (SourceLocation)
        relativeLocationAccessor()
    {
        return relativeLocationAccessorImpl(cursor.all);
    }

    private struct TokenRange
    {
        CXTranslationUnit cx;
        CXToken* tokens;
        uint numTokens;
        uint currentToken;

        Token makeToken(CXToken token)
        {
            return Token(
                clang_getTokenKind(token).toD,
                clang_getTokenSpelling(cx, token).toD,
                SourceRange(clang_getTokenExtent(cx, token)));
        }

        Token front()
        {
            return makeToken(tokens[currentToken]);
        }

        bool empty()
        {
            return numTokens == 0 || numTokens == currentToken;
        }

        void popFront()
        {
            currentToken++;
        }

        void dispose()
        {
            clang_disposeTokens(cx, tokens, numTokens);
        }
    }

    private static TokenRange tokenizeImpl(CXTranslationUnit cx, SourceRange extent)
    {
        auto range = TokenRange(cx);
        clang_tokenize(cx, extent.cx, &range.tokens, &range.numTokens);
        return range;
    }

    package static Token[] tokenize(CXTranslationUnit cx, SourceRange extent)
    {
        import std.array : array;
        import std.algorithm : stripRight;

        auto range = tokenizeImpl(cx, extent);
        auto tokens = range.array;
        range.dispose();

        // For some reason libclang returns some tokens out of cursors extent.cursor
        return tokens.stripRight!(token => !intersects(extent, token.extent));
    }

    package static Token[] tokenizeNoComments(CXTranslationUnit cx, SourceRange extent)
    {
        import std.array : array;
        import std.algorithm : filter, stripRight;

        auto range = tokenizeImpl(cx, extent);
        auto tokens = range.filter!(e => e.kind != TokenKind.comment).array;
        range.dispose();

        // For some reason libclang returns some tokens out of cursors extent.cursor
        return tokens.stripRight!(token => !intersects(extent, token.extent));
    }

    Token[] tokenize(SourceRange extent)
    {
        return tokenize(cx, extent);
    }

    Token[] tokenizeNoComments(SourceRange extent)
    {
        return tokenizeNoComments(cx, extent);
    }

    Token[] tokens()
    {
        return tokenize(extent(0, cast(uint) source.length));
    }

    Token[] tokensNoComments()
    {
        return tokenizeNoComments(extent(0, cast(uint) source.length));
    }

    bool isFileMultipleIncludeGuarded(string path)
    {
        auto file = clang_getFile(cx, path.toStringz);
        return clang_isFileMultipleIncludeGuarded(cx, file) != 0;
    }

    bool isMultipleIncludeGuarded()
    {
        return isFileMultipleIncludeGuarded(spelling);
    }

    string dumpAST(bool skipIncluded = true)
    {
        import std.array : appender;

        auto result = appender!string();

        if (skipIncluded)
        {
            File file = this.file;
            cursor.dumpAST(result, 0, &file);
        }
        else
        {
            cursor.dumpAST(result, 0);
        }

        return result.data;
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

Token[] tokenize(string source)
{
    Index index = Index(false, false);
    auto translUnit = TranslationUnit.parseString(index, source);
    return translUnit.tokenize(translUnit.extent(0, cast(uint) source.length));
}

Token[] tokenizeNoComments(string source)
{
    Index index = Index(false, false);
    auto translUnit = TranslationUnit.parseString(index, source);
    return translUnit.tokenizeNoComments(
        translUnit.extent(0, cast(uint) source.length));
}
