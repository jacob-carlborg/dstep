/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: October 05, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.MacroParser;

import std.array;
import std.meta;
import std.traits;
import std.variant;
import std.stdio;

import clang.c.Index;
import clang.Cursor;
import clang.Token;
import clang.Type;
import clang.Util;
import clang.SourceLocation;
import clang.SourceRange;

enum bool isStringValue(alias T) =
    is(typeof(T) : const char[]) &&
    !isAggregateType!(typeof(T)) &&
    !isStaticArray!(typeof(T));

/**
 * The accept family of functions parse tokens. In the case of successful parsing,
 * the function advances the beginning of the tokens to the next token and returns true.
 *
 * The parsing is successful, if the first token in tokens is of the specified kind
 * and its spelling matches one of the strings passed as Args.
 * It assigns the spelling of the token to the spelling parameter.
 */
bool accept(Args...)(ref Token[] tokens, ref string spelling, TokenKind kind)
    if (Args.length > 0 && allSatisfy!(isStringValue, Args))
{
    if (!tokens.empty && tokens.front.kind == kind)
    {
        foreach (arg; Args)
        {
            if (tokens.front.spelling == arg)
            {
                tokens = tokens[1 .. $];
                spelling = arg;
                return true;
            }
        }
    }

    return false;
}

bool accept(ref Token[] tokens, ref string spelling, TokenKind kind)
{
    if (!tokens.empty && tokens.front.kind == kind)
    {
        spelling = tokens.front.spelling;
        tokens = tokens[1 .. $];
        return true;
    }

    return false;
}

bool accept(Args...)(ref Token[] tokens, TokenKind kind)
    if (allSatisfy!(isStringValue, Args))
{
    if (!tokens.empty && tokens.front.kind == kind)
    {
        foreach (arg; Args)
        {
            if (tokens.front.spelling == arg)
            {
                tokens = tokens[1 .. $];
                return true;
            }
        }
    }

    return false;
}

bool accept(Args...)(ref Token[] tokens, ref string spelling)
    if (Args.length > 0 && allSatisfy!(isStringValue, Args))
{
    if (!tokens.empty)
    {
        foreach (arg; Args)
        {
            if (tokens.front.spelling == arg)
            {
                tokens = tokens[1 .. $];
                spelling = arg;
                return true;
            }
        }
    }

    return false;
}

bool acceptPunctuation(Args...)(ref Token[] tokens, ref string spelling)
    if (allSatisfy!(isStringValue, Args))
{
    return accept!(Args)(tokens, spelling, TokenKind.punctuation);
}

bool acceptPunctuation(Args...)(ref Token[] tokens)
    if (allSatisfy!(isStringValue, Args))
{
    return accept!(Args)(tokens, TokenKind.punctuation);
}

bool acceptIdentifier(ref Token[] tokens, ref string spelling)
{
    return accept(tokens, spelling, TokenKind.identifier);
}

bool acceptLiteral(ref Token[] tokens, ref string spelling)
{
    return accept(tokens, spelling, TokenKind.literal);
}

bool acceptKeyword(ref Token[] tokens, ref string spelling)
{
    return accept(tokens, spelling, TokenKind.keyword);
}

bool acceptStringLiteral(ref Token[] tokens, ref string spelling)
{
    import std.string : startsWith, endsWith;

    if (!tokens.empty && tokens.front.kind == TokenKind.literal)
    {
        spelling = tokens.front.spelling;

        if (!spelling.startsWith(`"`) || !spelling.endsWith(`"`))
            return false;

        tokens = tokens[1 .. $];
        return true;
    }

    return false;
}

Expression parseLeftAssoc(ResultExpr, alias parseChild, Ops...)(
    ref Token[] tokens,
    Cursor[string] table,
    bool defined) if (allSatisfy!(isStringValue, Ops))
{
    import std.traits;
    import std.range;

    auto local = tokens;

    ReturnType!parseChild[] exprs = [ parseChild(local, table, defined) ];
    string[] ops = [];

    if (!exprs[0].hasValue)
        return Expression.init;

    string op;
    while (accept!(Ops)(local, op, TokenKind.punctuation))
    {
        exprs ~= parseChild(local, table, defined);

        if (!exprs[$ - 1].hasValue)
            return Expression.init;

        ops ~= op;
    }

    tokens = local;

    if (exprs.length == 1)
        return exprs[0];

    ResultExpr result = new ResultExpr;
    result.left = exprs[0];
    result.right = exprs[1];
    result.operator = ops[0];

    foreach (expr, fop; zip(exprs[2 .. $], ops[1 .. $]))
    {
        ResultExpr parent = new ResultExpr;
        parent.left = result;
        parent.right = expr;
        parent.operator = fop;
        result = parent;
    }

    return Expression(result);
}

struct Identifier
{
    string spelling;

    string toString()
    {
        import std.format : format;

        return format("Identifier(spelling = %s)", spelling);
    }
}

struct TypeIdentifier
{
    Type type;
}

struct Literal
{
    string spelling;

    this (string spelling)
    {
        this.spelling = spelling;
    }

    string toString()
    {
        import std.format : format;

        return format("Literal(spelling = %s)", spelling);
    }
}

struct StringLiteral
{
    string spelling;

    this (string spelling)
    {
        this.spelling = spelling;
    }

    string toString()
    {
        import std.format : format;

        return format("Literal(spelling = %s)", spelling);
    }
}

struct StringifyExpr
{
    string spelling;

    this (string spelling)
    {
        this.spelling = spelling;
    }

    string toString()
    {
        import std.format : format;

        return format("StringifyExpr(spelling = %s)", spelling);
    }
}

class StringConcat
{
    Expression[] substrings;

    this (Expression[] substrings)
    {
        this.substrings = substrings;
    }

    override string toString()
    {
        import std.format : format;

        return format("StringConcat(substrings = %s)", substrings);
    }
}

class TokenConcat
{
    Expression[] subexprs;

    this (Expression[] subexprs)
    {
        this.subexprs = subexprs;
    }

    override string toString()
    {
        import std.format : format;

        return format("TokenConcat(subexprs = %s)", subexprs);
    }
}

class IndexExpr
{
    Expression subexpr;
    Expression index;

    override string toString()
    {
        import std.format : format;

        return format("IndexExpr(subexpr = %s, index = %s)", subexpr, index);
    }
}

class CallExpr
{
    Expression expr;
    Expression[] args;

    override string toString()
    {
        import std.format : format;

        return format("CallExpr(expr = %s, args = %s)", expr, args);
    }
}

class DotExpr
{
    Expression subexpr;
    string identifier;

    override string toString()
    {
        import std.format : format;

        return format(
            "DotExpr(subexpr = %s, identifier = %s)",
            subexpr,
            identifier);
    }
}

class ArrowExpr : DotExpr
{
    override string toString()
    {
        import std.format : format;

        return format(
            "ArrowExpr(subexpr = %s, identifier = %s)",
            subexpr,
            identifier);
    }
}

class SubExpr
{
    Expression subexpr;

    this (Expression subexpr)
    {
        this.subexpr = subexpr;
    }

    override string toString()
    {
        import std.format : format;

        return format("SubExpr(subexpr = %s)", subexpr);
    }
}

class UnaryExpr
{
    Expression subexpr;
    string operator;
    bool postfix = false;

    override string toString()
    {
        import std.format : format;

        return format(
            "UnaryExpr(subexpr = %s, operator = %s)",
            subexpr,
            operator);
    }
}

struct DefinedExpr
{
    string identifier;

    string toString()
    {
        import std.format : format;

        return format("DefinedExpr(identifier = %s)", identifier);
    }
}

struct SizeofType
{
    Type type;

    string toString()
    {
        import std.format : format;

        return format("SizeofType(type = %s)", type);
    }
}

class CastExpr
{
    Type type;
    Expression subexpr;

    override string toString()
    {
        import std.format : format;

        return format(
            "CastExpr(typename = %s, subexpr = %s)",
            type,
            subexpr);
    }
}

class BinaryExpr
{
    Expression left;
    Expression right;
    string operator;

    override string toString()
    {
        import std.format : format;
        import std.range : retro;
        import std.algorithm.searching : findSplit;
        import std.array : array;

        auto rname = findSplit(this.classinfo.name.retro, ".")[0].array;

        return format(
            "%s(left = %s, right = %s, operator = %s)",
            rname.retro,
            left,
            right,
            operator);
    }
}

class MulExpr : BinaryExpr
{ }

class AddExpr : BinaryExpr
{ }

class SftExpr : BinaryExpr
{ }

class RelExpr : BinaryExpr
{ }

class EqlExpr : BinaryExpr
{ }

class AndExpr : BinaryExpr
{ }

class XorExpr : BinaryExpr
{ }

class OrExpr : BinaryExpr
{ }

class LogicalAndExpr : BinaryExpr
{ }

class LogicalOrExpr : BinaryExpr
{ }

class CondExpr
{
    Expression expr;
    Expression left;
    Expression right;

    override string toString()
    {
        import std.format : format;
        import std.range : retro;
        import std.algorithm.searching : findSplit;
        import std.array : array;

        auto rname = findSplit(this.classinfo.name.retro, ".")[0].array;

        return format(
            "CondExpr(expr = %s, left = %s, right = %s)",
            expr,
            left,
            right);
    }
}

alias Expression = Algebraic!(
    Identifier,
    TypeIdentifier,
    Literal,
    StringLiteral,
    StringifyExpr,
    StringConcat,
    TokenConcat,
    IndexExpr,
    CallExpr,
    DotExpr,
    ArrowExpr,
    SubExpr,
    UnaryExpr,
    DefinedExpr,
    SizeofType,
    CastExpr,
    MulExpr,
    AddExpr,
    SftExpr,
    RelExpr,
    EqlExpr,
    AndExpr,
    XorExpr,
    OrExpr,
    LogicalAndExpr,
    LogicalOrExpr,
    CondExpr);

Expression debraced(Expression expression)
{
    if (!expression.hasValue)
        return expression;

    auto subExpr = expression.peek!SubExpr();

    return subExpr !is null ? subExpr.subexpr : expression;
}

Expression braced(Expression expression)
{
    if (!expression.hasValue)
        return expression;

    if (auto subExpr = expression.peek!Identifier())
        return expression;
    else if (auto subExpr = expression.peek!Literal())
        return expression;
    else if (auto subExpr = expression.peek!SubExpr())
        return expression;
    else
        return Expression(new SubExpr(expression));
}

Expression parseStringConcat(ref Token[] tokens)
{
    import std.array;

    auto local = tokens;

    Expression[] substrings;

    while (true)
    {
        string spelling;

        if (acceptStringLiteral(local, spelling))
        {
            substrings ~= Expression(StringLiteral(spelling));
        }
        else if (accept!("#")(local, TokenKind.punctuation))
        {
            if (!accept(local, spelling, TokenKind.identifier))
                return Expression.init;

            substrings ~= Expression(StringifyExpr(spelling));
        }
        else
        {
            break;
        }
    }

    if (substrings.length == 0)
        return Expression.init;

    tokens = local;

    if (substrings.length == 1)
        return substrings.front;

    return Expression(new StringConcat(substrings));
}

Expression parseTokenConcat(ref Token[] tokens)
{
    Expression parseSubexpr(ref Token[] tokens)
    {
        string spelling;

        if (acceptIdentifier(tokens, spelling))
            return Expression(Identifier(spelling));

        if (acceptLiteral(tokens, spelling))
            return Expression(Literal(spelling));

        return Expression.init;
    }

    auto local = tokens;

    Expression[] subexprs;
    auto first = parseSubexpr(local);

    if (first.hasValue)
    {
        if (!acceptPunctuation!("##")(local))
            return Expression.init;

        auto expr = parseSubexpr(local);

        if (expr.hasValue)
        {
            subexprs ~= first;
            subexprs ~= expr;

            tokens = local;

            while (acceptPunctuation!("##")(local))
            {
                expr = parseSubexpr(local);

                if (expr.hasValue)
                {
                    subexprs ~= expr;
                    tokens = local;
                }
                else
                {
                    break;
                }
            }

            return Expression(new TokenConcat(subexprs));
        }
    }

    return Expression.init;
}

Expression parsePrimaryExpr(ref Token[] tokens, Cursor[string] table, bool defined)
{
    string spelling;

    auto type = parseTypeName(tokens, table);

    if (type.isValid)
        return Expression(TypeIdentifier(type));

    if (accept(tokens, spelling, TokenKind.identifier))
        return Expression(Identifier(spelling));

    auto local = tokens;

    auto substrings = parseStringConcat(local);

    if (substrings.hasValue)
    {
        tokens = local;
        return substrings;
    }

    if (accept(local, spelling, TokenKind.literal))
    {
        tokens = local;
        return Expression(Literal(spelling));
    }

    if (!accept!("(")(local, TokenKind.punctuation))
        return Expression.init;

    auto subexpr = parseExpr(local, table, defined);

    if (!subexpr.hasValue)
        return Expression.init;

    if (!accept!(")")(local, TokenKind.punctuation))
        return Expression.init;

    tokens = local;

    return Expression(new SubExpr(subexpr));
}

Expression parseArg(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto local = tokens;

    auto expression = parseSftExpr(local, table, defined);

    if (expression.hasValue)
    {
        tokens = local;
        return expression;
    }

    auto type = parseTypeName(local, table);

    if (type.isValid)
    {
        tokens = local;
        expression = TypeIdentifier(type);
    }

    return expression;
}

Expression[] parseArgsList(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto local = tokens;

    Expression[] exprs = [ parseArg(local, table, defined) ];

    if (!exprs[0].hasValue)
        return null;

    while (true)
    {
        if (acceptPunctuation!(",")(local))
        {
            Expression expr = parseArg(local, table, defined);

            if (!expr.hasValue)
                break;

            exprs ~= expr;
        }
        else
        {
            break;
        }
    }

    tokens = local;

    return exprs;
}

Expression parsePostfixExpr(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto local = tokens;

    Expression expr = parsePrimaryExpr(local, table, defined);

    if (!expr.hasValue)
        return expr;

    string spelling;

    while (true)
    {
        if (acceptPunctuation!("[")(local))
        {
            auto index = parseExpr(local, table, defined);

            if (!index.hasValue)
                break;

            if (!acceptPunctuation!("]")(local))
                break;

            IndexExpr subexpr = new IndexExpr;
            subexpr.subexpr = expr;
            subexpr.index = index;
            expr = subexpr;
        }
        else if (acceptPunctuation!("(")(local))
        {
            if (acceptPunctuation!(")")(local))
            {
                CallExpr subexpr = new CallExpr;
                subexpr.expr = expr;
                subexpr.args = [];
                expr = subexpr;
            }
            else
            {
                auto args = parseArgsList(local, table, defined);

                if (args is null)
                    break;

                if (!acceptPunctuation!(")")(local))
                    break;

                CallExpr subexpr = new CallExpr;
                subexpr.expr = expr;
                subexpr.args = args;
                expr = subexpr;
            }
        }
        else if (acceptPunctuation!(".")(local) && acceptIdentifier(local, spelling))
        {
            DotExpr subexpr = new DotExpr;
            subexpr.subexpr = expr;
            subexpr.identifier = spelling;
            expr = subexpr;
        }
        else if (acceptPunctuation!("->")(local) && acceptIdentifier(local, spelling))
        {
            ArrowExpr subexpr = new ArrowExpr;
            subexpr.subexpr = expr;
            subexpr.identifier = spelling;
            expr = subexpr;
        }
        else if (acceptPunctuation!("++", "--")(local, spelling))
        {
            UnaryExpr subexpr = new UnaryExpr;
            subexpr.subexpr = expr;
            subexpr.operator = spelling;
            subexpr.postfix = true;
            expr = subexpr;
        }
        else
        {
            break;
        }
    }

    tokens = local;

    return expr;
}

Expression parseSizeofType(ref Token[] tokens, Cursor[string] table)
{
    auto local = tokens;

    if (acceptPunctuation!("(")(local))
    {
        Type type = parseTypeName(local, table);

        if (type.isValid && acceptPunctuation!(")")(local))
        {
            SizeofType expr = SizeofType();
            expr.type = type;
            tokens = local;
            return Expression(expr);
        }
    }

    return Expression.init;
}

Expression parseDefinedExpr(ref Token[] tokens)
{
    auto local = tokens;

    if (accept!("defined")(local, TokenKind.identifier))
    {
        string spelling;

        if (acceptIdentifier(local, spelling))
        {
            auto expr = DefinedExpr();
            expr.identifier = spelling;
            tokens = local;
            return Expression(expr);
        }

        if (acceptPunctuation!("(")(local) &&
            acceptIdentifier(local, spelling) &&
            acceptPunctuation!(")")(local))
        {
            auto expr = DefinedExpr();
            expr.identifier = spelling;
            tokens = local;
            return Expression(expr);
        }
    }

    return Expression.init;
}

Expression parseUnaryExpr(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto local = tokens;

    string spelling;

    if (accept!("++", "--")(local, spelling, TokenKind.punctuation))
    {
        Expression subexpr = parseUnaryExpr(local, table, defined);

        if (subexpr.hasValue)
        {
            UnaryExpr expr = new UnaryExpr;
            expr.subexpr = subexpr;
            expr.operator = spelling;
            tokens = local;
            return Expression(expr);
        }
    }

    if (accept!("&", "*", "+", "-", "~", "!")(local, spelling, TokenKind.punctuation))
    {
        Expression subexpr = parseCastExpr(local, table, defined);

        if (subexpr.hasValue)
        {
            UnaryExpr expr = new UnaryExpr;
            expr.subexpr = subexpr;
            expr.operator = spelling;
            tokens = local;
            return Expression(expr);
        }
    }

    if (accept!("sizeof")(local, spelling, TokenKind.keyword))
    {
        auto sizeofExpr = parseSizeofType(local, table);

        if (sizeofExpr.hasValue)
        {
            tokens = local;
            return sizeofExpr;
        }

        Expression subexpr = parseUnaryExpr(local, table, defined);

        if (subexpr.hasValue)
        {
            UnaryExpr expr = new UnaryExpr;
            expr.subexpr = subexpr;
            expr.operator = spelling;
            tokens = local;
            return Expression(expr);
        }
    }

    if (defined)
    {
        auto expr = parseDefinedExpr(local);

        if (expr.hasValue)
        {
            tokens = local;
            return expr;
        }
    }

    return parsePostfixExpr(tokens, table, defined);
}

Expression parseCastExpr(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto local = tokens;

    if (!accept!("(")(local, TokenKind.punctuation))
        return parseUnaryExpr(tokens, table, defined);

    Type type = parseTypeName(local, table);

    if (!type.isValid)
        return parseUnaryExpr(tokens, table, defined);

    if (!accept!(")")(local, TokenKind.punctuation))
        return parseUnaryExpr(tokens, table, defined);

    auto subexpr = parseCastExpr(local, table, defined);

    if (!subexpr.hasValue)
        return parseUnaryExpr(tokens, table, defined);

    tokens = local;

    CastExpr result = new CastExpr;
    result.type = type;
    result.subexpr = subexpr;

    return Expression(result);
}

alias parseMulExpr = parseLeftAssoc!(MulExpr, parseCastExpr, "*", "/", "%");
alias parseAddExpr = parseLeftAssoc!(AddExpr, parseMulExpr, "+", "-");
alias parseSftExpr = parseLeftAssoc!(SftExpr, parseAddExpr, "<<", ">>");
alias parseRelExpr = parseLeftAssoc!(RelExpr, parseSftExpr, "<", ">", "<=", ">=");
alias parseEqlExpr = parseLeftAssoc!(EqlExpr, parseRelExpr, "==", "!=");
alias parseAndExpr = parseLeftAssoc!(AndExpr, parseEqlExpr, "&");
alias parseXorExpr = parseLeftAssoc!(XorExpr, parseAndExpr, "^");
alias parseOrExpr = parseLeftAssoc!(OrExpr, parseXorExpr, "|");
alias parseLogicalAndExpr = parseLeftAssoc!(LogicalAndExpr, parseOrExpr, "&&");
alias parseLogicalOrExpr = parseLeftAssoc!(LogicalOrExpr, parseLogicalAndExpr, "||");

Expression parseCondExpr(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto local = tokens;

    Expression expr = parseLogicalOrExpr(local, table, defined);

    if (!expr.hasValue)
        return Expression.init;

    tokens = local;

    if (acceptPunctuation!("?")(local))
    {
        Expression left = parseExpr(local, table, defined);

        if (left.hasValue && acceptPunctuation!(":")(local))
        {
            Expression right = parseCondExpr(local, table, defined);

            if (right.hasValue)
            {
                CondExpr supexpr = new CondExpr;
                supexpr.expr = expr;
                supexpr.left = left;
                supexpr.right = right;
                expr = supexpr;

                tokens = local;
            }
        }
    }

    return expr;
}

bool parseBasicSpecifier(ref Token[] tokens, ref string spelling, Cursor[string] table)
{
    import std.meta : AliasSeq;

    alias specifiers = AliasSeq!(
        "void",
        "char",
        "short",
        "int",
        "long",
        "float",
        "double",
        "signed",
        "unsigned",
        // "__complex__", TBD
        // "_Complex", TBD
        "bool",
        "_Bool");

    return accept!(specifiers)(tokens, spelling);
}

bool parseRecordSpecifier(ref Token[] tokens, ref Type type, Cursor[string] table)
{
    auto local = tokens;
    string spelling;
    string keywordType;

    if (accept!("struct", "union")(local, keywordType, TokenKind.keyword) &&
        acceptIdentifier(local, spelling))
    {
        if (auto ptr = (keywordType ~ " " ~ spelling in table))
        {
            type = ptr.type;
            tokens = local;
            return true;
        }
    }

    return false;
}

bool parseEnumSpecifier(ref Token[] tokens, ref Type type, Cursor[string] table)
{
    auto local = tokens;
    string spelling;

    if (acceptIdentifier(local, spelling))
    {
        if (auto ptr = ("enum " ~ spelling in table))
        {
            type = ptr.type;
            tokens = local;
            return true;
        }
    }

    return false;
}

bool parseTypedefName(ref Token[] tokens, ref Type type, Cursor[string] table)
{
    auto local = tokens;
    string spelling;

    if (acceptIdentifier(local, spelling))
    {
        if (auto ptr = (spelling in table))
        {
            type = Type.makeTypedef(spelling, ptr.type.canonical);

            tokens = local;

            return true;
        }
    }

    return false;
}

bool parseComplexSpecifier(ref Token[] tokens, ref Type type, Cursor[string] table)
{
    return parseRecordSpecifier(tokens, type, table) ||
        parseEnumSpecifier(tokens, type, table) ||
        parseTypedefName(tokens, type, table);
}

bool parseTypeQualifier(ref Token[] tokens, ref string spelling)
{
    import std.meta : AliasSeq;

    alias qualifiers = AliasSeq!(
        "const",
        "volatile",
        "_Atomic");

    return accept!(qualifiers)(tokens, spelling);
}

bool parseSpecifierQualifierList(
    ref Token[] tokens,
    ref Type type,
    Cursor[string] table)
{
    auto local = tokens;

    Set!string specifiers;
    Set!string qualifiers;

    while (true)
    {
        string spelling;

        if (parseBasicSpecifier(local, spelling, table))
        {
            if (type.isValid)
                return false;

            if (specifiers.contains(spelling))
            {
                if (spelling == "long")
                {
                    if (specifiers.contains("__llong"))
                        return false;
                    else
                        spelling = "__llong";
                }
                else
                {
                    return false;
                }
            }

            specifiers.add(spelling);
        }
        else if (parseComplexSpecifier(local, type, table))
        {
            if (specifiers.length != 0)
                return false;
        }
        else if (parseTypeQualifier(local, spelling))
        {
            if (qualifiers.contains(spelling))
                return false;

            qualifiers.add(spelling);
        }
        else
        {
            break;
        }
    }

    if (specifiers.length != 0)
    {
        if(!basicSpecifierListToType(type, specifiers))
            return false;
    }

    if (qualifiers.contains("const"))
        type.isConst = true;

    if (qualifiers.contains("volatile"))
        type.isVolatile = true;

    tokens = local;

    return true;
}

bool parseQualifierList(
    ref Token[] tokens,
    ref Type type)
{
    auto local = tokens;

    Set!string qualifiers;

    while (true)
    {
        string spelling;

        if (parseTypeQualifier(local, spelling))
        {
            if (qualifiers.contains(spelling))
                return false;

            qualifiers.add(spelling);
        }
        else
        {
            break;
        }
    }

    if (qualifiers.contains("const"))
        type.isConst = true;

    if (qualifiers.contains("volatile"))
        type.isVolatile = true;

    tokens = local;

    return true;
}

bool basicSpecifierListToType(ref Type type, Set!string specifiers)
{
    if (specifiers.contains("void"))
    {
        if (specifiers.length != 1)
            return false;

        type = Type(CXTypeKind.void_, "void");
        return true;
    }

    if (specifiers.contains("bool") || specifiers.contains("_Bool"))
    {
        if (specifiers.length != 1)
            return false;

        type = Type(CXTypeKind.bool_, "bool");
        return true;
    }

    if (specifiers.contains("float"))
    {
        if (specifiers.length != 1)
            return false;

        type = Type(CXTypeKind.float_, "float");
        return true;
    }

    if (specifiers.contains("double"))
    {
        if (specifiers.contains("long"))
        {
            if (specifiers.length != 2)
                return false;

            type = Type(CXTypeKind.longDouble, "long double");

            return true;
        }

        if (specifiers.length != 1)
            return false;

        type = Type(CXTypeKind.double_, "double");

        return true;
    }

    if ((specifiers.contains("signed") && specifiers.contains("unsigned")) ||
        (specifiers.contains("char") && specifiers.contains("short")) ||
        (specifiers.contains("char") && specifiers.contains("long")) ||
        (specifiers.contains("char") && specifiers.contains("__llong")) ||
        (specifiers.contains("short") && specifiers.contains("long")) ||
        (specifiers.contains("short") && specifiers.contains("__llong")))
        return false;

    if (specifiers.contains("char"))
    {
        if (specifiers.contains("signed"))
        {
            if (specifiers.length != 2)
                return false;

            type = Type(CXTypeKind.sChar, "signed char");
        }
        else if (specifiers.contains("unsigned"))
        {
            if (specifiers.length != 2)
                return false;

            type = Type(CXTypeKind.uChar, "unsigned char");
        }
        else
        {
            if (specifiers.length != 1)
                return false;

            type = Type(CXTypeKind.charS, "char");
        }

        return true;
    }

    if (specifiers.contains("short"))
    {
        if (specifiers.contains("unsigned"))
            type = Type(CXTypeKind.uShort, "unsigned short");
        else
            type = Type(CXTypeKind.short_, "short");

        return true;
    }

    if (specifiers.contains("__llong"))
    {
        if (specifiers.contains("unsigned"))
            type = Type(CXTypeKind.uLongLong, "unsigned long long");
        else
            type = Type(CXTypeKind.longLong, "long long");

        return true;
    }

    if (specifiers.contains("long"))
    {
        if (specifiers.contains("unsigned"))
            type = Type(CXTypeKind.uLong, "unsigned long");
        else
            type = Type(CXTypeKind.long_, "long");

        return true;
    }

    if (specifiers.contains("int"))
    {
        if (specifiers.contains("unsigned"))
            type = Type(CXTypeKind.uInt, "unsigned int");
        else
            type = Type(CXTypeKind.int_, "int");

        return true;
    }

    if (specifiers.contains("unsigned"))
    {
        type = Type(CXTypeKind.uInt, "unsigned int");
        return true;
    }

    if (specifiers.contains("signed"))
    {
        type = Type(CXTypeKind.int_, "int");
        return true;
    }

    return false;
}

bool parsePointer(ref Token[] tokens, ref Type type)
{
    if (acceptPunctuation!("*")(tokens))
    {
        type = Type.makePointer(type);

        if (!parsePointer(tokens, type))
        {
            if (parseQualifierList(tokens, type))
                parsePointer(tokens, type);
        }

        return true;
    }
    else
    {
        return false;
    }
}

bool parseAbstractDeclarator(ref Token[] tokens, ref Type type, Cursor[string] table)
{
    return parsePointer(tokens, type);
}

Type parseTypeName(ref Token[] tokens, Cursor[string] table)
{
    auto local = tokens;

    Type type;

    if (!parseSpecifierQualifierList(local, type, table))
        return type;

    parseAbstractDeclarator(local, type, table);

    tokens = local;

    return type;
}

Expression parseExpr(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto concatExpr = parseTokenConcat(tokens);

    if (concatExpr.hasValue)
        return concatExpr;

    auto condExpr = parseCondExpr(tokens, table, defined);

    if (condExpr.hasValue)
        return condExpr;

    return Expression.init;
}

Expression parseExpr(ref Token[] tokens, bool defined)
{
    Cursor[string] table;

    return parseCondExpr(tokens, table, defined);
}

Expression parseEnumMember(Token[] tokens, Cursor[string] table)
{
    string member;

    if (!acceptIdentifier(tokens, member))
        return Expression.init;

    if (!acceptPunctuation!("=")(tokens, member))
        return Expression.init;

    auto expression = parseExpr(tokens, table, false);

    if (tokens.empty)
        return expression;
    else
        return Expression.init;
}

string[] parseMacroParams(ref Token[] tokens)
{
    auto local = tokens;

    string[] params;

    string param;

    if (!accept(local, param, TokenKind.identifier))
        return [];

    params ~= param;

    while (accept!(",")(local, TokenKind.punctuation))
    {
        if (!accept(local, param, TokenKind.identifier))
            return null;

        params ~= param;
    }

    tokens = local;

    return params;
}

class MacroDefinition
{
    Cursor cursor;
    string spelling;
    string[] params;
    bool aliasOrConst;
    Expression expr;

    override string toString()
    {
        import std.format : format;

        return format(
            "MacroDefinition(spelling = %s, params = %s, aliasOrConst = %s, expr = %s)",
            spelling,
            params,
            aliasOrConst,
            expr);
    }

    void dumpAST(ref Appender!string result, size_t indent)
    {
        import std.format;
        import std.array : replicate;
        import std.string : join;

        result.put(" ".replicate(indent));

        if (aliasOrConst)
            formattedWrite(result, "MacroDefinition %s", spelling);
        else
            formattedWrite(result, "MacroDefinition %s(%s)", spelling, join(params, ", "));
    }

    string dumpAST()
    {
        auto result = Appender!string();
        dumpAST(result, 0);
        return result.data;
    }
}

MacroDefinition parseMacroDefinition(
    ref Token[] tokens,
    Cursor[string] table,
    bool defined = false)
{
    auto local = tokens;

    if (!accept!("#")(local, TokenKind.punctuation))
        return null;

    if (!accept!("define")(local, TokenKind.identifier))
        return null;

    MacroDefinition result = parsePartialMacroDefinition(local, table, defined);

    if (result !is null)
        tokens = local;

    return result;
}

MacroDefinition parsePartialMacroDefinition(
    ref Token[] tokens,
    Cursor[string] table,
    bool defined = false)
{
    auto local = tokens;

    MacroDefinition result = new MacroDefinition;

    if (!accept(local, result.spelling, TokenKind.identifier))
        return null;

    // Functional macros mustn't contain space before parentheses of parameter list.
    bool space =
        tokens.length > 2 &&
        tokens[0].extent.end.offset == tokens[1].extent.start.offset;

    if (space && accept!("(")(local, TokenKind.punctuation))
    {
        if (!accept!(")")(local, TokenKind.punctuation))
        {
            result.params = parseMacroParams(local);

            if (!accept!(")")(local, TokenKind.punctuation))
                return null;
        }
    }
    else
    {
        result.aliasOrConst = true;
    }

    result.expr = parseExpr(local, table, defined);

    if (!local.empty)
    {
        return null;
    }
    else
    {
        tokens = local;
        return result;
    }
}

MacroDefinition[] parseMacroDefinitions(Range)(
    Range cursors,
    Cursor[string] types)
{
    import std.algorithm;
    import std.array;

    alias predicate = (Cursor cursor) =>
        cursor.kind == CXCursorKind.macroDefinition;

    auto definitions = cursors.filter!predicate();

    auto macroDefinitions = appender!(MacroDefinition[]);

    foreach (definition; definitions) {
        auto tokens = definition.tokens;
        auto parsed = parsePartialMacroDefinition(tokens, types);

        if (parsed !is null && parsed.expr.hasValue)
        {
            parsed.cursor = definition;
            macroDefinitions.put(parsed);

            if (parsed.aliasOrConst)
            {
                auto debraced = parsed.expr.debraced;

                if (debraced.peek!TypeIdentifier)
                    types[parsed.spelling] = definition;
            }
        }
    }

    return macroDefinitions.data;
}
