/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jul 08, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Preprocessor;

import std.array;

import clang.Cursor;
import clang.Index;
import clang.SourceRange;
import clang.Token;
import clang.TranslationUnit;

public import dstep.translator.MacroDefinitionParser;

class ConditionalDirective : Directive
{
    Expression condition;
    Directive[] branches;
    Directive endif;
}

class PragmaDirective : Directive
{
}

class UndefDirective : Directive
{
    string identifier;
}

struct TokenizedDirectiveRange
{
    string source;
    Token[] tokens;
    Token[] result;

    this(Token[] tokens, string source = null)
    {
        this.tokens = tokens;
        this.source = source;

        popFront();
    }

    @property bool empty() const
    {
        return result.empty;
    }

    @property Token[] front()
    {
        return result;
    }

    void popFront()
    {
        findNext();
        yield();
    }

    @property string toString() const
    {
        return "TokenizedDirectiveRange(..)";
    }

    private void findNext()
    {
        if (1 < tokens.length &&
            tokens[0].spelling == "#" &&
            isDirective(tokens[1]))
            return;

        while (2 < tokens.length &&
            (tokens[1].spelling != "#" ||
            tokens[0].location.line >= tokens[1].location.line ||
            !isDirective(tokens[2])))
            tokens.popFront();

        if (2 < tokens.length)
            tokens.popFront();
        else
            tokens = Token[].init;
    }

    private size_t countEscaped(string range)
    {
        return 0;
    }

    private void yield()
    {
        result = Token[].init;

        size_t itr = 0;

        while (itr + 1 < tokens.length)
        {
            auto loc0 = tokens[itr].location;
            auto loc1 = tokens[itr + 1].location;

            ptrdiff_t diff = loc1.line - loc0.line;

            if (0 < diff &&
                (source == null ||
                countEscaped(source[loc0.offset .. loc1.offset]) < diff))
                break;

            ++itr;
        }

        if (itr + 1 < tokens.length)
        {
            result = tokens[0 .. itr + 1];
            tokens = tokens[itr + 1 .. $];
        }
        else
        {
            result = tokens;
            tokens = Token[].init;
        }
    }

    private static bool isDirective(Token token)
    {
        switch (token.spelling)
        {
            case "elif":
            case "else":
            case "endif":
            case "error":
            case "define":
            case "if":
            case "ifdef":
            case "ifndef":
            case "include":
            case "line":
            case "pragma":
            case "undef":
                return true;

            default:
                return false;
        }
    }
}

TokenizedDirectiveRange tokenizedDirectives(Token[] tokens, string source = null)
{
    return TokenizedDirectiveRange(tokens, source);
}

TokenizedDirectiveRange tokenizedDirectives(string source)
{
    return tokenizedDirectives(tokenizeNoComments(source), source);
}

struct DirectiveRange
{
    TranslationUnit translUnit;
    TokenizedDirectiveRange tokensRange;
    Directive front_;

    this(TranslationUnit translUnit)
    {
        tokensRange = tokenizedDirectives(translUnit.tokensNoComments, translUnit.source);

        this.translUnit = translUnit;

        popFront();
    }

    @property bool empty() const
    {
        return front_ is null;
    }

    @property Directive front()
    {
        return front_;
    }

    void popFront()
    {
        front_ = parseDirective(tokensRange.front);
        tokensRange.popFront();

        while (!tokensRange.empty && !front_)
        {
            front_ = parseDirective(tokensRange.front);
            tokensRange.popFront();
        }
    }

    @property string toString() const
    {
        return "DirectiveRange(..)";
    }

    bool acceptDirective(alias spelling)(ref Token[] tokens)
    {
        if (1 < tokens.length &&
            tokens[0].spelling == "#" &&
            tokens[1].spelling == spelling)
        {
            tokens = tokens[2 .. $];
            return true;
        }

        return false;
    }

    Expression parseIf(Token[] tokens)
    {
        if (acceptDirective!"if"(tokens))
        {
            auto expr = parseExpr(tokens, true);

            if (expr && tokens.empty)
                return expr;
        }

        return null;
    }

    Expression parseIfdef(Token[] tokens)
    {
        string spelling;

        if (tokens.length == 3 &&
            acceptDirective!"ifdef"(tokens) &&
            acceptIdentifier(tokens, spelling))
        {
            auto expr = new DefinedExpr();
            expr.identifier = spelling;

            return expr;
        }

        return null;
    }

    Expression parseIfndef(Token[] tokens)
    {
        string spelling;

        if (tokens.length == 3 &&
            acceptDirective!"ifndef"(tokens) &&
            acceptIdentifier(tokens, spelling))
        {
            auto defined = new DefinedExpr();
            defined.identifier = spelling;

            auto expr = new UnaryExpr();
            expr.subexpr = defined;
            expr.operator = "!";

            return expr;
        }

        return null;
    }

    Expression parseElif(Token[] tokens)
    {
        if (acceptDirective!"elif"(tokens))
        {
            auto expr = parseExpr(tokens, true);

            if (expr && tokens.empty)
                return expr;
        }

        return null;
    }

    Expression parseIfCombined(ref DirectiveKind kind, Token[] tokens)
    {
        if (auto expr = parseIf(tokens))
        {
            kind = DirectiveKind.if_;
            return expr;
        }

        if (auto expr = parseIfdef(tokens))
        {
            kind = DirectiveKind.ifdef;
            return expr;
        }

        if (auto expr = parseIfndef(tokens))
        {
            kind = DirectiveKind.ifndef;
            return expr;
        }

        if (auto expr = parseElif(tokens))
        {
            kind = DirectiveKind.elif;
            return expr;
        }

        return null;
    }

    bool parseElse(ref DirectiveKind kind, Token[] tokens)
    {
        kind = DirectiveKind.else_;
        return acceptDirective!"else"(tokens) && tokens.empty;
    }

    bool parseEndif(ref DirectiveKind kind, Token[] tokens)
    {
        kind = DirectiveKind.endif;
        return acceptDirective!"endif"(tokens) && tokens.empty;
    }

    private Directive parseConditional(Token[] tokens)
    {
        DirectiveKind kind;

        if (auto expr = parseIfCombined(kind, tokens))
        {
            auto directive = new ConditionalDirective;
            directive.kind = kind;
            directive.condition = expr;
            directive.tokens = tokens;
            directive.extent = tokens.extent;
            return directive;
        }

        if (parseElse(kind, tokens) || parseEndif(kind, tokens))
        {
            auto directive = new Directive;
            directive.kind = kind;
            directive.tokens = tokens;
            directive.extent = tokens.extent;
            return directive;
        }

        return null;
    }

    private Directive parseDefine(Token[] tokens, Cursor[string] table)
    {
        auto directive = parseMacroDefinition(tokens, table, true);

        if (tokens.empty)
            return directive;

        return null;
    }

    private Directive parseDefine(Token[] tokens)
    {
        Cursor[string] table;

        return parseDefine(tokens, table);
    }

    private Directive parseError(Token[] tokens)
    {
        return null;
    }

    Directive parseUndef(Token[] tokens)
    {
        string spelling;

        if (tokens.length == 3 &&
            acceptDirective!"undef"(tokens) &&
            acceptIdentifier(tokens, spelling))
        {
            auto expr = new UndefDirective();
            expr.identifier = spelling;

            return expr;
        }

        return null;
    }

    Directive parseInclude(Token[] tokens)
    {
        return null;
    }

    Directive parseLine(Token[] tokens)
    {
        return null;
    }

    Directive parsePragma(Token[] tokens)
    {
        if (acceptDirective!"pragma"(tokens))
        {
            if (tokens.length == 1)
            {
                if (tokens[0].spelling == "once")
                {
                    auto directive = new PragmaDirective();
                    directive.kind = DirectiveKind.pragmaOnce;
                    directive.tokens = tokens;
                    directive.extent = tokens.extent;
                    return directive;
                }
            }
        }

        return null;
    }

    private Directive parseDirective(Token[] tokens)
    {
        if (auto directive = parseConditional(tokens))
            return directive;
        else if (auto directive = parseDefine(tokens))
            return directive;
        else if (auto directive = parseError(tokens))
            return directive;
        else if (auto directive = parseInclude(tokens))
            return directive;
        else if (auto directive = parseLine(tokens))
            return directive;
        else if (auto directive = parsePragma(tokens))
            return directive;
        else if (auto directive = parseUndef(tokens))
            return directive;
        else
            return null;
    }
}

void updateConditions(Directive[] directives)
{
    void update(ref Directive[] directives)
    {
        Directive[] branches = [ directives.front ];
        directives.popFront();

        while (!directives.empty)
        {
            if (directives.front.kind == DirectiveKind.endif)
            {
                foreach (branch; branches)
                {
                    if (auto conditional = cast(ConditionalDirective) branch)
                    {
                        conditional.branches = branches;
                        conditional.endif = directives.front;
                    }
                }

                directives.popFront();
                break;
            }
            else if (
                directives.front.kind == DirectiveKind.elif ||
                directives.front.kind == DirectiveKind.else_)
            {
                branches ~= directives.front;
                directives.popFront();
            }
            else if (directives.front.kind.isIf)
            {
                update(directives);
            }
            else
            {
                directives.popFront();
            }
        }
    }

    void updateTopLevel(ref Directive[] directives)
    {
        while (!directives.empty)
        {
            if (directives.front.kind.isIf)
                update(directives);
            else
                directives.popFront();
        }
    }

    updateTopLevel(directives);
}

Directive[] directives(TranslationUnit translUnit)
{
    auto directives = DirectiveRange(translUnit).array;

    updateConditions(directives);

    return directives;
}

Directive[] directives(string source)
{
    import std.array : array;

    Index index = Index(false, false);

    return directives(TranslationUnit.parseString(index, source));
}

unittest
{
    import std.array : array;

    auto x0 = tokenizedDirectives("").array;

    assert(x0.length == 0);


    auto x1 = tokenizedDirectives("int x = 3;").array;

    assert(x1.length == 0);


    auto x2 = tokenizedDirectives(q"C
int x = 3;

int f()
{
    return 42;
}
C").array;

    assert(x2.length == 0);


    auto x3 = tokenizedDirectives(q"C
#define FOO
C").array;

    assert(x3.length == 1);


    auto x4 = tokenizedDirectives(q"C
#define FOO 0

#define BAR 1

#define BAZ 2
C").array;

    assert(x4.length == 3);


    auto x5 = tokenizedDirectives(q"C
#if FOO == 0

#elif FOO == 1

#else

#endif
C").array;

    assert(x5.length == 4);


    auto x6 = tokenizedDirectives(q"C
#ifdef FOO

#endif

#ifndef FOO

#endif
C").array;

    assert(x6.length == 4);


    auto x7 = tokenizedDirectives(q"C
#pragma once
#include <stdio.h>
#define FOO
C").array;

    assert(x7.length == 3);


    auto x8 = tokenizedDirectives(q"C
#pragma once
#line 44
C").array;

    assert(x8.length == 2);


    auto x9 = tokenizedDirectives("#pragma once").array;

    assert(x9.length == 1);
    assert(x9[0][0].spelling == "#");
    assert(x9[0][1].spelling == "pragma");
    assert(x9[0][2].spelling == "once");


    auto x10 = tokenizedDirectives(q"C
#define FOO 0
#define BAR 1
#define BAZ 2
C").array;

    assert(x10.length == 3);
    assert(x10[0][0].spelling == "#");
    assert(x10[0][1].spelling == "define");
    assert(x10[0][2].spelling == "FOO");
    assert(x10[0][3].spelling == "0");

    assert(x10.length == 3);
    assert(x10[1][0].spelling == "#");
    assert(x10[1][1].spelling == "define");
    assert(x10[1][2].spelling == "BAR");
    assert(x10[1][3].spelling == "1");

    assert(x10.length == 3);
    assert(x10[2][0].spelling == "#");
    assert(x10[2][1].spelling == "define");
    assert(x10[2][2].spelling == "BAZ");
    assert(x10[2][3].spelling == "2");
}

unittest
{
    auto x0 = directives(``);

    assert(x0.length == 0);
}

unittest
{
    auto x0 = directives(`#define FOO`);

    assert(x0.length == 1);
    assert(cast(MacroDefinition) x0[0]);

    auto foo = cast(MacroDefinition) x0[0];

    assert(foo.spelling == "FOO");
}

unittest
{
    auto x0 = directives(`#pragma once`);

    assert(x0.length == 1);
    assert(cast(PragmaDirective) x0[0]);

    auto foo = cast(PragmaDirective) x0[0];

    assert(foo.kind == DirectiveKind.pragmaOnce);
}

// Test parsing of basic conditions.
unittest
{
    auto case0 = directives(`
    #ifndef FOO

    #endif`);

    assert(case0.length == 2);
    assert(case0[0].kind == DirectiveKind.ifndef);
    assert(case0[1].kind == DirectiveKind.endif);

    auto cond0 = cast(ConditionalDirective) case0[0];

    assert(cond0);

    auto unary0 = cast(UnaryExpr) cond0.condition;

    assert(unary0);
    assert(unary0.operator == "!");

    auto defined0 = cast(DefinedExpr) unary0.subexpr;

    assert(defined0);
    assert(defined0.identifier == "FOO");


    auto case1 = directives(`
    #ifdef FOO

    #endif`);

    assert(case1.length == 2);
    assert(cast(ConditionalDirective) case1[0]);

    auto cond1 = cast(ConditionalDirective) case1[0];

    assert(cond1);
    assert(cond1.condition);


    auto case2 = directives(`
    #if 1

    #endif`);

    assert(case2.length == 2);
    assert(cast(ConditionalDirective) case2[0]);

    auto cond2 = cast(ConditionalDirective) case2[0];

    assert(cond2);
    assert(cond2.condition);
}

// Test parsing of multi-branch directives.
unittest
{
    auto case0 = directives(`
    #if FOO

    #elif BAR

    #elif BAZ

    #else

    #endif`);

    assert(case0.length == 5);

    assert(case0[0].kind == DirectiveKind.if_);
    assert(case0[1].kind == DirectiveKind.elif);
    assert(case0[2].kind == DirectiveKind.elif);
    assert(case0[3].kind == DirectiveKind.else_);
    assert(case0[4].kind == DirectiveKind.endif);

    auto cond0 = cast(ConditionalDirective) case0[0];
    auto cond1 = cast(ConditionalDirective) case0[1];
    auto cond2 = cast(ConditionalDirective) case0[2];

    assert(cond0);
    assert(cond1);
    assert(cond2);

    auto id0 = cast(Identifier) cond0.condition;
    auto id1 = cast(Identifier) cond1.condition;
    auto id2 = cast(Identifier) cond2.condition;

    assert(id0);
    assert(id0.spelling == "FOO");
    assert(id1);
    assert(id1.spelling == "BAR");
    assert(id2);
    assert(id2.spelling == "BAZ");
}

// Parse `defined` operator.
unittest
{
    auto case0 = directives(`
    #if defined FOO

    #endif`);

    auto cond0 = cast(ConditionalDirective) case0[0];

    assert(cond0);


    auto case1 = directives(`
    #if defined(FOO)

    #endif`);

    auto cond1 = cast(ConditionalDirective) case1[0];

    assert(cond1);

    auto expr = cast(DefinedExpr) cond1.condition;

    assert(expr);
    assert(expr.identifier == "FOO");
}

// Test if branch pointer are arranged correctly.
unittest
{
    auto case0 = directives(`
    #if 1

    #endif`);

    auto if0 = cast(ConditionalDirective) case0[0];

    assert(if0);
    assert(if0.branches.length == 1);
    assert(if0.endif == case0[1]);


    auto case1 = directives(`
    #if 1

    #else

    #endif`);

    auto if1 = cast(ConditionalDirective) case1[0];

    assert(if1);
    assert(if1.branches.length == 2);
    assert(if1.endif == case1[2]);


    auto case2 = directives(`
    #if 1

    #elif defined FOO

    #else

    #endif`);

    auto if2 = cast(ConditionalDirective) case2[0];

    assert(if2);
    assert(if2.branches.length == 3);
    assert(if2.branches[0] == case2[0]);
    assert(if2.branches[1] == case2[1]);
    assert(if2.branches[2] == case2[2]);
    assert(if2.endif == case2[3]);


    auto case3 = directives(`
    #if 1

    #elif defined FOO

    #else

    #endif

    #define BAR
    #undef BAR
    #define BAZ

    #if 0

    #else

    #endif

    #define FUN(x, y) x + y`);

    assert(case3.length == 11);

    auto if3_0 = cast(ConditionalDirective) case3[0];
    auto if3_1 = cast(ConditionalDirective) case3[7];

    assert(if3_0);
    assert(if3_1);

    assert(if3_0.branches.length == 3);
    assert(if3_1.branches.length == 2);

    assert(if3_0.branches[0] == case3[0]);
    assert(if3_0.branches[1] == case3[1]);
    assert(if3_0.branches[2] == case3[2]);
    assert(if3_0.endif == case3[3]);

    assert(if3_1.branches[0] == case3[7]);
    assert(if3_1.branches[1] == case3[8]);
    assert(if3_1.endif == case3[9]);


    auto case4 = directives(`
    #if 1

    #elif defined FOO

        #ifdef BAR

        #else

        #endif

    #else

    #endif`);


    assert(case4.length == 7);

    auto if4_0 = cast(ConditionalDirective) case4[0];
    auto if4_1 = cast(ConditionalDirective) case4[2];

    assert(if4_0.branches[0] == case4[0]);
    assert(if4_0.branches[1] == case4[1]);
    assert(if4_0.branches[2] == case4[5]);
    assert(if4_0.endif == case4[6]);

    assert(if4_1.branches[0] == case4[2]);
    assert(if4_1.branches[1] == case4[3]);
    assert(if4_1.endif == case4[4]);
}

// A case with space between directive and comment.
unittest
{
    auto case1 = tokenizedDirectives(`
    /* Header comment. */

    #ifndef __FOO
    #define __FOO

    /* Comment before variable. */
    int variable;

    #endif`).array;

    assert(case1.length == 3);
}

// A case with comment after directive.
unittest
{
    auto case0 = tokenizedDirectives(`
    #ifndef FOO /* Comment. */

    #endif`).array;

    assert(case0.length == 2);

    assert(case0[0].length == 3);
}
