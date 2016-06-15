/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Mar 21, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

module dstep.translator.Context;

import mambo.core._;

import clang.c.Index;
import clang.Cursor;
import clang.TranslationUnit;

import dstep.translator.CommentIndex;
import dstep.translator.IncludeHandler;
import dstep.translator.MacroDefinition;
import dstep.translator.MacroIndex;
import dstep.translator.Options;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.TypedefIndex;

class Context
{
    public MacroIndex macroIndex;
    public TranslationUnit translUnit;

    private string[Cursor] anonymousNames;
    private bool[Cursor] alreadyDefined_;
    private IncludeHandler includeHandler_;
    private CommentIndex commentIndex_ = null;
    private TypedefIndex typedefIndex_ = null;
    private Translator translator_ = null;
    private Output globalScope_ = null;
    private bool[string] typeNames_;

    public MacroDefinition[string] macroDefinitions;
    string macroLinkage = "extern (D)";

    public this(TranslationUnit translUnit, Options options, Translator translator = null)
    {
        this.translUnit = translUnit;
        macroIndex = new MacroIndex(translUnit);
        includeHandler_ = new IncludeHandler();

        if (options.enableComments)
            commentIndex_ = new CommentIndex(translUnit);

        typedefIndex_ = new TypedefIndex(translUnit);

        if (translator !is null)
            translator_ = translator;
        else
            translator_ = new Translator(translUnit, options);

        globalScope_ = new Output();
        typeNames_ = collectTypeNames(translUnit);
    }

    public string macroLinkagePrefix()
    {
        return macroLinkage == "" ? "" : macroLinkage ~ " ";
    }

    public string getAnonymousName (Cursor cursor)
    {
        if (auto name = cursor in anonymousNames)
            return *name;

        return "";
    }

    public string generateAnonymousName (Cursor cursor)
    {
        import std.format : format;

        auto name = getAnonymousName(cursor);

        if (name.isBlank)
        {
            name = format("_Anonymous_%d", anonymousNames.length);
            anonymousNames[cursor] = name;
        }

        return name;
    }

    public string spelling (Cursor cursor)
    {
        auto ptr = cursor in anonymousNames;
        return ptr !is null ? *ptr : cursor.spelling;
    }

    public IncludeHandler includeHandler()
    {
        return includeHandler_;
    }

    public CommentIndex commentIndex()
    {
        return commentIndex_;
    }

    @property public bool[string] typeNames()
    {
        return typeNames_;
    }

    public TypedefIndex typedefIndex()
    {
        return typedefIndex_;
    }

    public bool alreadyDefined(in Cursor cursor)
    {
        return (cursor in alreadyDefined_) !is null;
    }

    public void markAsDefined(in Cursor cursor)
    {
        alreadyDefined_[cursor] = true;
    }

    public Cursor typedefParent(in Cursor cursor)
    {
        return typedefIndex_.typedefParent(cursor);
    }

    public string translateSpelling(in Cursor cursor)
    {
        auto typedefp = typedefParent(cursor.canonical);

        if (typedefp.isValid &&
            (cursor.spelling == typedefp.spelling || cursor.spelling == ""))
            return typedefp.spelling;
        else
            return cursor.spelling == ""
                ? generateAnonymousName(cursor)
                : cursor.spelling;
    }

    public Translator translator()
    {
        return translator_;
    }

    public Output globalScope()
    {
        return globalScope_;
    }
}

string[] cursorScope(Context context, Cursor cursor)
{
    string[] result;

    void cursorScope(Context context, Cursor cursor, ref string[] result)
    {
        string spelling;

        switch (cursor.kind)
        {
            case CXCursorKind.CXCursor_StructDecl:
            case CXCursorKind.CXCursor_UnionDecl:
            case CXCursorKind.CXCursor_EnumDecl:
                cursorScope(context, cursor.semanticParent, result);
                spelling = context.spelling(cursor);
                break;

            default:
                return;
        }

        result ~= spelling;
    }

    cursorScope(context, cursor, result);

    return result;
}

string cursorScopeString(Context context, Cursor cursor)
{
    import std.array : join;
    return join(cursorScope(context, cursor), ".");
}

/**
 * Returns true, if there is a variable, of type represented by cursor, among
 * children of its parent.
 */
bool variablesInParentScope(Cursor cursor)
{
    import std.algorithm.iteration : filter;

    auto parent = cursor.semanticParent;
    auto canonical = cursor.canonical;

    bool predicate(Cursor a)
    {
        return (
            a.kind == CXCursorKind.CXCursor_FieldDecl ||
            a.kind == CXCursorKind.CXCursor_VarDecl) &&
            a.type.declaration.canonical == canonical;
    }

    return !filter!(predicate)(parent.children).empty;
}

/**
  * Returns true, if cursor can be translated as anonymous.
  */
bool shouldBeAnonymous(Context context, Cursor cursor)
{
    return cursor.type.isAnonymous &&
        context.typedefIndex.typedefParent(cursor).isEmpty;
}

/**
 * Returns true, if cursor is in the global scope.
 */
bool isGlobal(Cursor cursor)
{
    return cursor.semanticParent.kind == CXCursorKind.CXCursor_TranslationUnit;
}

/**
 * The collectTypeNames function scans the whole AST of the translation unit and produces
 * a set of the type names in global scope.
 *
 * The type names are required for the parsing of C code (e.g. macro definition bodies),
 * as C grammar isn't context free.
 */

bool[string] collectTypeNames(TranslationUnit translUnit)
{
    void collectBasicTypes(ref bool[string] result)
    {
        result["void"] = true;
        result["char"] = true;
        result["signed char"] = true;
        result["unsigned char"] = true;
        result["short"] = true;
        result["signed short"] = true;
        result["unsigned short"] = true;
        result["signed"] = true;
        result["unsigned"] = true;
        result["int"] = true;
        result["signed int"] = true;
        result["unsigned int"] = true;
        result["long"] = true;
        result["signed long"] = true;
        result["unsigned long"] = true;
        result["long long"] = true;
        result["signed long long"] = true;
        result["unsigned long long"] = true;
        result["float"] = true;
        result["double"] = true;
    }

    void collectTypeNames(ref bool[string] result, Cursor parent)
    {
        foreach (cursor, _; parent.all)
        {
            switch (cursor.kind)
            {
                case CXCursorKind.CXCursor_TypedefDecl:
                    result[cursor.spelling] = true;
                    break;

                case CXCursorKind.CXCursor_StructDecl:
                    result[cursor.spelling] = true;
                    break;

                default:
                    break;
            }
        }
    }

    bool[string] result;

    collectBasicTypes(result);
    collectTypeNames(result, translUnit.cursor);

    return result;
}

