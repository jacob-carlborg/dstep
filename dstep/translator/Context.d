/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Mar 21, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Context;

import std.algorithm;

import clang.c.Index;
import clang.Cursor;
import clang.Index;
import clang.SourceRange;
import clang.TranslationUnit;

import dstep.core.Optional;

import dstep.translator.CommentIndex;
import dstep.translator.IncludeHandler;
import dstep.translator.MacroDefinition;
import dstep.translator.MacroIndex;
import dstep.translator.Options;
import dstep.translator.Output;
import dstep.translator.Translator;
import dstep.translator.TypedefIndex;
import dstep.translator.HeaderIndex;

class Context
{
    public MacroIndex macroIndex;
    public TranslationUnit translUnit;

    private string[Cursor] anonymousNames;
    private bool[Cursor] alreadyDefined_;
    private IncludeHandler includeHandler_;
    private CommentIndex commentIndex_ = null;
    private TypedefIndex typedefIndex_ = null;
    private HeaderIndex headerIndex_ = null;
    private Translator translator_ = null;
    private Output globalScope_ = null;
    private Cursor[string] typeNames_;
    private Cursor[string] constNames_;
    private string[Cursor] translatedSpellings;
    private AnnotatedDeclaration[string] _annotatedDeclarations;

    Options options;

    const string source;

    public this(TranslationUnit translUnit, Options options, Translator translator = null)
    {
        this.translUnit = translUnit;
        macroIndex = new MacroIndex(translUnit);
        includeHandler_ = new IncludeHandler(headerIndex, options);

        foreach (item; options.globalImports)
            includeHandler_.addImport(item);

        foreach (item; options.publicGlobalImports)
            includeHandler_.addImport(item, Visibility.public_);

        this.options = options;

        if (options.enableComments)
        {
            auto location = macroIndex.includeGuardLocation;

            if (location[0])
                commentIndex_ = new CommentIndex(
                    translUnit,
                    location[1]);
            else
                commentIndex_ = new CommentIndex(translUnit);
        }

        typedefIndex_ = new TypedefIndex(translUnit, options.isWantedCursorForTypedefs);

        if (translator !is null)
            translator_ = translator;
        else
            translator_ = new Translator(translUnit, options);

        globalScope_ = new Output();
        collectGlobalNames(translUnit, typeNames_, constNames_);
        source = translUnit.source;
    }

    static Context fromString(string source, Options options = Options.init)
    {
        import clang.Compiler : Compiler;

        Compiler compiler;

        auto translationUnit = TranslationUnit.parseString(
            Index(false, false),
            source,
            compiler.internalFlags,
            compiler.internalHeaders);

        return new Context(translationUnit, options);
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
        import std.range : empty;

        auto name = getAnonymousName(cursor);

        if (name.empty)
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

    public Cursor[string] typeNames()
    {
        return typeNames_;
    }

    public Cursor[string] constNames()
    {
        return constNames_;
    }

    public TypedefIndex typedefIndex()
    {
        return typedefIndex_;
    }

    public HeaderIndex headerIndex()
    {
        if (headerIndex_ is null)
            headerIndex_ = new HeaderIndex(this.translUnit);

        return headerIndex_;
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

    public bool isInsideTypedef(in Cursor cursor)
    {
        assert(cursor.kind == CXCursorKind.enumDecl
            || cursor.kind == CXCursorKind.structDecl
            || cursor.kind == CXCursorKind.unionDecl);

        if (auto typedef_ = typedefIndex_.typedefParent(cursor))
        {
            auto inner = cursor.extent;
            auto outer = typedef_.extent;
            return contains(outer, inner);
        }
        else
        {
            return false;
        }
    }

    private string translateSpellingImpl(in Cursor cursor)
    {
        return cursor.spelling == ""
            ? generateAnonymousName(cursor)
            : cursor.spelling;
    }

    public string translateSpelling(in Cursor cursor)
    {
        if (auto spelling = (cursor in translatedSpellings))
        {
            return *spelling;
        }
        else
        {
            auto spelling = translateSpellingImpl(cursor);
            translatedSpellings[cursor] = spelling;
            return spelling;
        }
    }

    public void defineSpellingTranslation(in Cursor cursor, string spelling)
    {
        translatedSpellings[cursor] = spelling;
    }

    private void printCollisionWarning(
        string spelling,
        Cursor cursor,
        Cursor collision)
    {
        import std.format : format;
        import std.stdio : writeln;

        if (options.printDiagnostics)
        {
            auto message = format(
                "%s: warning: a type renamed to '%s' due to the " ~
                "collision with the symbol declared in %s",
                cursor.location.toColonSeparatedString,
                spelling,
                collision.location.toColonSeparatedString);

            writeln(message);
        }
    }

    private void throwCollisionError(
        string spelling,
        Cursor cursor,
        Cursor collision) {
        import std.format : format;

        throw new TranslationException(
            format(
                "%s: error: a type name '%s' " ~
                "collides with the symbol declared in %s",
                cursor.location.toColonSeparatedString,
                spelling,
                collision.location.toColonSeparatedString));
    }

    public string translateTagSpelling(Cursor cursor)
    {
        if (auto cached = (cursor.canonical in translatedSpellings))
        {
            return *cached;
        }

        string spelling;

        if (cursor.spelling == "stat"
            && headerIndex.searchKnownModules(cursor) == "core.sys.posix.sys.stat")
        {
            spelling = "stat_t";
        }
        else
        {
            auto typedefp = typedefParent(cursor.canonical);

            if (typedefp.isValid && cursor.spelling == "")
            {
                spelling = typedefp.spelling;
            }
            else
            {
                string tentative = translateSpellingImpl(cursor);

                spelling = tentative;

                if (options.collisionAction != CollisionAction.ignore)
                {
                    auto collision = spelling in macroIndex.globalCursors;

                    while (collision &&
                        collision.canonical != cursor.canonical &&
                        collision.canonical != typedefParent(cursor.canonical))
                    {
                        if (options.collisionAction == CollisionAction.abort)
                            throwCollisionError(spelling, cursor, *collision);

                        spelling ~= "_";
                        printCollisionWarning(spelling, cursor, *collision);
                        collision = spelling in macroIndex.globalCursors;
                    }
                }
            }
        }

        translatedSpellings[cursor.canonical] = spelling;
        return spelling;
    }

    public Translator translator()
    {
        return translator_;
    }

    public Output globalScope()
    {
        return globalScope_;
    }

    auto annotatedDeclarations() => _annotatedDeclarations;

    void addAnnotatedDeclaration(StructData structData)
    {
        _annotatedDeclarations.require(structData.name, new AnnotatedDeclaration(structData.name)).
            declaration = structData;
    }

    void addAnnotatedMember(string context, StructData.Body member)
    {
        _annotatedDeclarations.require(context, new AnnotatedDeclaration(context))
            .addMember(member);
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
            case CXCursorKind.structDecl:
            case CXCursorKind.unionDecl:
            case CXCursorKind.enumDecl:
                cursorScope(context, cursor.lexicalParent, result);
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
            a.kind == CXCursorKind.fieldDecl ||
            a.kind == CXCursorKind.varDecl) &&
            a.type.undecorated.declaration.canonical == canonical;
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
    return cursor.semanticParent.kind == CXCursorKind.translationUnit;
}

/**
 * Returns true, if cursor is in the global scope.
 */
bool isGlobalLexically(Cursor cursor)
{
    return cursor.lexicalParent.kind == CXCursorKind.translationUnit;
}

/**
 * The collectGlobalTypes function scans the whole AST of the translation unit and produces
 * a set of the type names in global scope.
 *
 * The type names are required for the parsing of C code (e.g. macro definition bodies),
 * as C grammar isn't context free.
 */
void collectGlobalNames(
    TranslationUnit translUnit,
    ref Cursor[string] types,
    ref Cursor[string] consts)
{
    void collectEnumMembers(
        Cursor parent,
        ref Cursor[string] consts)
    {
        foreach (cursor; parent.all)
        {
            switch (cursor.kind)
            {
                case CXCursorKind.enumConstantDecl:
                    consts[cursor.spelling] = cursor;
                    break;

                default:
                    break;
            }
        }
    }

    void collectGlobalTypes(
        Cursor parent,
        ref Cursor[string] types,
        ref Cursor[string] consts)
    {
        foreach (cursor, _; parent.all)
        {
            switch (cursor.kind)
            {
                case CXCursorKind.typedefDecl:
                    types[cursor.spelling] = cursor;
                    break;

                case CXCursorKind.structDecl:
                    types["struct " ~ cursor.spelling] = cursor;
                    break;

                case CXCursorKind.unionDecl:
                    types["union " ~ cursor.spelling] = cursor;
                    break;

                case CXCursorKind.enumDecl:
                    types["enum " ~ cursor.spelling] = cursor;
                    collectEnumMembers(cursor, consts);
                    break;

                default:
                    break;
            }
        }
    }

    collectGlobalTypes(translUnit.cursor, types, consts);
}

/// A declaration that has been annotated with API notes.
class AnnotatedDeclaration
{
    immutable string name;
    Optional!StructData declaration;

    private StructData.Body[] _members;

    this(string name)
    {
        this.name = name;
    }

    StructData.Body[] members()
    {
        return _members;
    }

    void addMember(StructData.Body member)
    {
        _members ~= member;
    }

    void addMembersToDeclaration()
    {
        declaration.each!((decl) {
            foreach (member; members)
                decl.addDeclaration(member);
        });
    }
}
