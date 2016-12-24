/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 1, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Cursor;

import std.array : appender, Appender;
import std.conv : to;
import std.string;

import clang.c.Index;
import clang.Index;
import clang.File;
import clang.SourceLocation;
import clang.SourceRange;
import clang.Token;
import clang.TranslationUnit;
import clang.Type;
import clang.Util;
import clang.Visitor;

struct Cursor
{
    mixin CX;

    private static const CXCursorKind[string] predefined;

    static this()
    {
        predefined = queryPredefined();
    }

    @property static Cursor empty ()
    {
        auto r = clang_getNullCursor();
        return Cursor(r);
    }

    @property string spelling () const
    {
        return toD(clang_getCursorSpelling(cx));
    }

    @property CXCursorKind kind () const
    {
        return clang_getCursorKind(cx);
    }

    @property bool isPreprocessor () const
    {
        CXCursorKind kind = clang_getCursorKind(cx);
        return CXCursorKind.CXCursor_FirstPreprocessing <= kind &&
            kind <= CXCursorKind.CXCursor_LastPreprocessing;
    }

    @property SourceLocation location () const
    {
        return SourceLocation(clang_getCursorLocation(cx));
    }

    @property File file () const
    {
        return location.file;
    }

    @property string path () const
    {
        return file.name;
    }

    @property Token[] tokens() const
    {
        CXTranslationUnit translUnit = clang_Cursor_getTranslationUnit(cx);

        return TranslationUnit.tokenize(translUnit, extent);
    }

    @property SourceRange extent() const
    {
        return SourceRange(clang_getCursorExtent(cx));
    }

    @property Type type () const
    {
        auto r = clang_getCursorType(cx);
        return Type(r);
    }

    @property Type underlyingType() const
    {
        return Type(clang_getTypedefDeclUnderlyingType(cx));
    }

    @property bool isDeclaration ()
    {
        return clang_isDeclaration(cx.kind) != 0;
    }

    @property DeclarationVisitor declarations ()
    {
        return DeclarationVisitor(cx);
    }

    @property ObjcCursor objc ()
    {
        return ObjcCursor(this);
    }

    @property FunctionCursor func ()
    {
        return FunctionCursor(this);
    }

    @property EnumCursor enum_ ()
    {
        return EnumCursor(this);
    }

    @property bool isValid ()
    {
        return !clang_isInvalid(cx.kind);
    }

    @property bool isEmpty ()
    {
        return clang_Cursor_isNull(cx) != 0;
    }

    @property Visitor all () const
    {
        return Visitor(this);
    }

    @property InOrderVisitor allInOrder () const
    {
        return InOrderVisitor(this);
    }

    private Cursor[] childrenImpl(T)(bool ignorePredefined) const
    {
        import std.array : appender;

        Cursor[] result;
        auto app = appender(result);

        if (ignorePredefined && isTranslationUnit)
        {
            foreach (cursor, _; T(this))
            {
                if (!cursor.isPredefined)
                    app.put(cursor);
            }
        }
        else
        {
            foreach (cursor, _; T(this))
                app.put(cursor);
        }

        return app.data;
    }

    Cursor[] children(bool ignorePredefined = false) const
    {
        return childrenImpl!Visitor(ignorePredefined);
    }

    Cursor[] childrenInOrder(bool ignorePredefined = false) const
    {
        return childrenImpl!InOrderVisitor(ignorePredefined);
    }

    Cursor child() const
    {
        foreach (child; all)
            return child;

        return Cursor.empty;
    }

    Cursor findChild(CXCursorKind kind) const
    {
        foreach (child; all)
        {
            if (child.kind == kind)
                return child;
        }

        return Cursor.empty();
    }

    Cursor[] filterChildren(CXCursorKind kind)
    {
        import std.array;

        auto result = Appender!(Cursor[])();

        foreach (child; all)
        {
            if (child.kind == kind)
                result.put(child);
        }

        return result.data();
    }

    Cursor[] filterChildren(CXCursorKind[] kinds ...)
    {
        import std.array;

        auto result = Appender!(Cursor[])();

        foreach (child; all)
        {
            foreach (kind; kinds)
            {
                if (child.kind == kind)
                {
                    result.put(child);
                    break;
                }
            }
        }

        return result.data();
    }

    Cursor semanticParent() const
    {
        return Cursor(clang_getCursorSemanticParent(cast(CXCursor) cx));
    }

    Cursor lexicalParent() const
    {
        return Cursor(clang_getCursorLexicalParent(cast(CXCursor) cx));
    }

    @property CXLanguageKind language ()
    {
        return clang_getCursorLanguage(cx);
    }

    equals_t opEquals (in Cursor cursor) const
    {
        return clang_equalCursors(cast(CXCursor) cursor.cx, cast(CXCursor) cx) != 0;
    }

    hash_t toHash () const
    {
        return clang_hashCursor(cast(CXCursor) cx);
    }

    bool isDefinition () const
    {
        return clang_isCursorDefinition(cast(CXCursor) cx) != 0;
    }

    bool isTranslationUnit() const
    {
        return clang_isTranslationUnit(kind) != 0;
    }

    string includedPath ()
    {
        auto file = clang_getIncludedFile(cx);
        return toD(clang_getFileName(file));
    }

    private static CXCursorKind[string] queryPredefined()
    {
        CXCursorKind[string] result;

        Index index = Index(false, false);
        TranslationUnit unit = TranslationUnit.parseString(
            index,
            "",
            []);

        foreach (cursor; unit.cursor.children)
            result[cursor.spelling] = cursor.kind;

        auto version_ = clangVersion();

        if (version_.major == 3 && version_.minor == 7)
            result["__int64"] = CXCursorKind.CXCursor_MacroDefinition;

        return result;
    }

    bool isPredefined() const
    {
        auto xkind = spelling in predefined;
        return xkind !is null && *xkind == kind;
    }

    TranslationUnit translationUnit ()
    {
        return TranslationUnit(clang_Cursor_getTranslationUnit(cx));
    }

    @property Cursor definition () const
    {
        return Cursor(clang_getCursorDefinition(cast(CXCursor) cx));
    }

    Cursor referenced () const
    {
        return Cursor(clang_getCursorReferenced(cast(CXCursor) cx));
    }

    Cursor canonical () const
    {
        return Cursor(clang_getCanonicalCursor(cast(CXCursor) cx));
    }

    Cursor opCast(T)() const if (is(T == Cursor))
    {
        return this;
    }

    bool opCast(T)() if (is(T == bool))
    {
        return !isEmpty && isValid;
    }

    void dumpAST(ref Appender!string result, size_t indent, File* file)
    {
        import std.format;
        import std.array : replicate;
        import std.algorithm.comparison : min;

        string stripPrefix(string x)
        {
            immutable string prefix = "CXCursor_";
            immutable size_t prefixSize = prefix.length;
            return x.startsWith(prefix) ? x[prefixSize..$] : x;
        }

        string prettyTokens(Token[] tokens, size_t limit = 5)
        {
            string prettyToken(Token token)
            {
                immutable string prefix = "CXToken_";
                immutable size_t prefixSize = prefix.length;
                auto x = to!string(token.kind);
                return format(
                    "%s \"%s\"",
                    x.startsWith(prefix) ? x[prefixSize .. $] : x,
                    token.spelling);
            }

            auto result = appender!string("[");

            if (tokens.length != 0)
            {
                result.put(prettyToken(tokens[0]));

                foreach (Token token; tokens[1..min($, limit)])
                {
                    result.put(", ");
                    result.put(prettyToken(token));
                }
            }

            if (tokens.length > limit)
                result.put(", ..]");
            else
                result.put("]");

            return result.data;
        }

        immutable size_t step = 4;

        result.put(" ".replicate(indent));
        formattedWrite(
            result,
            "%s \"%s\" [%d..%d] %s\n",
            stripPrefix(to!string(kind)),
            spelling,
            extent.start.offset,
            extent.end.offset,
            prettyTokens(tokens));

        if (file)
        {
            foreach (cursor, _; allInOrder)
            {
                if (!cursor.isPredefined() && cursor.file == *file)
                    cursor.dumpAST(result, indent + step);
            }
        }
        else
        {
            foreach (cursor, _; allInOrder)
            {
                if (!cursor.isPredefined())
                    cursor.dumpAST(result, indent + step);
            }
        }
    }

    void dumpAST(ref Appender!string result, size_t indent)
    {
        dumpAST(result, indent, null);
    }

    string dumpAST()
    {
        auto result = appender!string();
        dumpAST(result, 0);
        return result.data;
    }

    @property string toString()
    {
        import std.format : format;
        return format("Cursor(kind = %s, spelling = %s)", kind, spelling);
    }
}

struct ObjcCursor
{
    Cursor cursor;
    alias cursor this;

    @property ObjCInstanceMethodVisitor instanceMethods ()
    {
        return ObjCInstanceMethodVisitor(cursor);
    }

    @property ObjCClassMethodVisitor classMethods ()
    {
        return ObjCClassMethodVisitor(cursor);
    }

    @property ObjCPropertyVisitor properties ()
    {
        return ObjCPropertyVisitor(cursor);
    }

    @property Cursor superClass ()
    {
        foreach (cursor, parent ; TypedVisitor!(CXCursorKind.CXCursor_ObjCSuperClassRef)(cursor))
            return cursor;

        return Cursor.empty;
    }

    @property ObjCProtocolVisitor protocols ()
    {
        return ObjCProtocolVisitor(cursor);
    }

    @property Cursor category ()
    {
        assert(cursor.kind == CXCursorKind.CXCursor_ObjCCategoryDecl);

        foreach (c, _ ; TypedVisitor!(CXCursorKind.CXCursor_ObjCClassRef)(cursor))
            return c;

        assert(0, "This cursor does not have a class reference.");
    }
}

struct FunctionCursor
{
    Cursor cursor;
    alias cursor this;

    @property Type resultType ()
    {
        auto r = clang_getCursorResultType(cx);
        return Type(r);
    }

    @property bool isVariadic ()
    {
        return type.func.isVariadic;
    }

    @property ParamVisitor parameters ()
    {
        return ParamVisitor(cx);
    }
}

struct ParamCursor
{
    Cursor cursor;
    alias cursor this;
}

struct EnumCursor
{
    Cursor cursor;
    alias cursor this;

    @property string value ()
    {
        //return type.kind.isUnsigned ? unsignedValue.toString : signedValue.toString;
        return signedValue.to!string;
    }

    @property long signedValue ()
    {
        return clang_getEnumConstantDeclValue(cx);
    }

    @property ulong unsignedValue ()
    {
        return clang_getEnumConstantDeclUnsignedValue(cx);
    }
}
