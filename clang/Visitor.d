/**
 * Copyright: Copyright (c) 2012 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Visitor;

import clang.c.Index;
import clang.Cursor;
import clang.SourceLocation;
import clang.SourceRange;
import clang.TranslationUnit;

struct Visitor
{
    alias int delegate (ref Cursor, ref Cursor) Delegate;
    alias int delegate (Delegate dg) OpApply;

    private CXCursor cursor;

    this (CXCursor cursor)
    {
        this.cursor = cursor;
    }

    this (Cursor cursor)
    {
        this.cursor = cursor.cx;
    }

    int opApply (Delegate dg)
    {
        auto data = OpApplyData(dg);
        clang_visitChildren(cursor, &visitorFunction, cast(CXClientData) &data);

        return data.returnCode;
    }

    int opApply(int delegate (ref Cursor) dg)
    {
        int wrapper (ref Cursor cursor, ref Cursor)
        {
            return dg(cursor);
        }

        auto data = OpApplyData(&wrapper);
        clang_visitChildren(cursor, &visitorFunction, cast(CXClientData) &data);

        return data.returnCode;
    }

private:

    extern (C) static CXChildVisitResult visitorFunction (
        CXCursor cursor,
        CXCursor parent,
        CXClientData data)
    {
        auto tmp = cast(OpApplyData*) data;

        with (CXChildVisitResult)
        {
            auto dCursor = Cursor(cursor);
            auto dParent = Cursor(parent);
            auto r = tmp.dg(dCursor, dParent);
            tmp.returnCode = r;
            return r ? CXChildVisit_Break : CXChildVisit_Continue;
        }
    }

    static struct OpApplyData
    {
        int returnCode;
        Delegate dg;

        this (Delegate dg)
        {
            this.dg = dg;
        }
    }

    template Constructors ()
    {
        private Visitor visitor;

        this (Visitor visitor)
        {
            this.visitor = visitor;
        }

        this (CXCursor cursor)
        {
            visitor = Visitor(cursor);
        }

        this (Cursor cursor)
        {
            visitor = Visitor(cursor);
        }
    }
}

struct InOrderVisitor
{
    alias int delegate (ref Cursor, ref Cursor) Delegate;

    private Cursor cursor;

    this (CXCursor cursor)
    {
        this.cursor = Cursor(cursor);
    }

    this (Cursor cursor)
    {
        this.cursor = cursor;
    }

    int opApply (Delegate dg)
    {
        import std.array;

        auto visitor = Visitor(cursor);
        int result = 0;

        auto macrosAppender = appender!(Cursor[])();
        size_t itr = 0;

        foreach (cursor, _; visitor)
        {
            if (cursor.isPreprocessor)
                macrosAppender.put(cursor);
        }

        auto macros = macrosAppender.data;
        auto query = cursor.translationUnit
            .relativeLocationAccessorImpl(macros);

        ulong macroIndex = macros.length != 0
            ? query(macros[0].location)
            : ulong.max;

        size_t jtr = 0;

        foreach (cursor, parent; visitor)
        {
            if (!cursor.isPreprocessor)
            {
                ulong cursorIndex = query(cursor.location);

                while (macroIndex < cursorIndex)
                {
                    Cursor macroParent = macros[jtr].semanticParent;

                    result = dg(macros[jtr], macroParent);

                    if (result)
                        return result;

                    ++jtr;

                    macroIndex = jtr < macros.length
                        ? query(macros[jtr].location)
                        : ulong.max;
                }

                result = dg(cursor, parent);

                if (result)
                    return result;
            }
        }

        while (jtr < macros.length)
        {
            Cursor macroParent = macros[jtr].semanticParent;

            result = dg(macros[jtr], macroParent);

            if (result)
                return result;

            ++jtr;
        }

        return result;
    }

private:

}

struct DeclarationVisitor
{
    mixin Visitor.Constructors;

    int opApply (Visitor.Delegate dg)
    {
        foreach (cursor, parent ; visitor)
            if (cursor.isDeclaration)
                if (auto result = dg(cursor, parent))
                    return result;

        return 0;
    }
}

struct TypedVisitor (CXCursorKind kind)
{
    private Visitor visitor;

    this (Visitor visitor)
    {
        this.visitor = visitor;
    }

    this (CXCursor cursor)
    {
        this(Visitor(cursor));
    }

    this (Cursor cursor)
    {
        this(cursor.cx);
    }

    int opApply (Visitor.Delegate dg)
    {
        foreach (cursor, parent ; visitor)
            if (cursor.kind == kind)
                if (auto result = dg(cursor, parent))
                    return result;

        return 0;
    }
}

alias TypedVisitor!(CXCursorKind.CXCursor_ObjCInstanceMethodDecl) ObjCInstanceMethodVisitor;
alias TypedVisitor!(CXCursorKind.CXCursor_ObjCClassMethodDecl) ObjCClassMethodVisitor;
alias TypedVisitor!(CXCursorKind.CXCursor_ObjCPropertyDecl) ObjCPropertyVisitor;
alias TypedVisitor!(CXCursorKind.CXCursor_ObjCProtocolRef) ObjCProtocolVisitor;

struct ParamVisitor
{
    mixin Visitor.Constructors;

    int opApply (int delegate (ref ParamCursor) dg)
    {
        foreach (cursor, parent ; visitor)
            if (cursor.kind == CXCursorKind.CXCursor_ParmDecl)
            {
                auto paramCursor = ParamCursor(cursor);

                if (auto result = dg(paramCursor))
                    return result;
            }

        return 0;
    }

    @property size_t length ()
    {
        auto type = Cursor(visitor.cursor).type;

        if (type.isValid)
            return type.func.arguments.length;

        else
        {
            size_t i;

            foreach (_ ; this)
                i++;

            return i;
        }
    }

    @property bool any ()
    {
        return length > 0;
    }

    @property bool isEmpty ()
    {
        return !any;
    }

    @property ParamCursor first ()
    {
        assert(any, "Cannot get the first parameter of an empty parameter list");

        foreach (c ; this)
            return c;

        assert(0, "Cannot get the first parameter of an empty parameter list");
    }
}