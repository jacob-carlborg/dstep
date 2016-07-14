/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jul 08, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Preprocessor;

import clang.Token;
import clang.TranslationUnit;

struct TokenizedDirectiveRange
{
    string source;
    Token[] tokens;
    Token[] result;

    private void findNext()
    {
        if (1 < tokens.length &&
            tokens[0].spelling == "#" &&
            isDirective(tokens[1]))
            return;

        while (2 < tokens.length &&
            (tokens[1].spelling != "#" ||
            tokens[0].location.line != tokens[1].location.line - 1 ||
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
}

TokenizedDirectiveRange tokenizedDirectives(Token[] tokens, string source = null)
{
    return TokenizedDirectiveRange(tokens, source);
}

TokenizedDirectiveRange directives(string source)
{
    return directives(tokenize(source), source);
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

    auto x0 = directives("").array;

    assert(x0.length == 0);


    auto x1 = directives("int x = 3;").array;

    assert(x1.length == 0);


    auto x2 = directives(q"D
int x = 3;

int f()
{
    return 42;
}
D").array;

    assert(x2.length == 0);


    auto x3 = directives(q"D
#define FOO
D").array;

    assert(x3.length == 1);


    auto x4 = directives(q"D
#define FOO 0

#define BAR 1

#define BAZ 2
D").array;

    assert(x4.length == 3);


    auto x5 = directives(q"D
#if FOO == 0

#elif FOO == 1

#else

#endif
D").array;

    assert(x5.length == 4);


    auto x6 = directives(q"D
#ifdef FOO

#endif

#ifndef FOO

#endif
D").array;

    assert(x6.length == 4);


    auto x7 = directives(q"D
#pragma once
#include <stdio.h>
#define FOO
D").array;

    assert(x7.length == 3);


    auto x8 = directives(q"D
#pragma once
#line 44
D").array;

    assert(x8.length == 2);


    auto x9 = directives("#pragma once").array;

    assert(x9.length == 1);
    assert(x9[0][0].spelling == "#");
    assert(x9[0][1].spelling == "pragma");
    assert(x9[0][2].spelling == "once");


    auto x10 = directives(q"D
#define FOO 0
#define BAR 1
#define BAZ 2
D").array;

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

