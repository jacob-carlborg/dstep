/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 03, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

module dstep.translator.MacroDefinition;

import std.array : Appender;
import std.traits;
import std.meta;

import clang.c.Index;
import clang.Cursor;
import clang.Token;

import dstep.translator.Context;
import dstep.translator.Output;

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

bool accept(Args...)(ref TokenRange tokens, ref string spelling, TokenKind kind)
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

bool accept(ref TokenRange tokens, ref string spelling, TokenKind kind)
{
    if (!tokens.empty && tokens.front.kind == kind)
    {
        spelling = tokens.front.spelling;
        tokens = tokens[1 .. $];
        return true;
    }

    return false;
}

bool accept(Args...)(ref TokenRange tokens, TokenKind kind)
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

bool acceptPunctuation(Args...)(ref TokenRange tokens, ref string spelling)
    if (allSatisfy!(isStringValue, Args))
{
    return accept!(Args)(tokens, spelling, TokenKind.punctuation);
}

bool acceptPunctuation(Args...)(ref TokenRange tokens)
    if (allSatisfy!(isStringValue, Args))
{
    return accept!(Args)(tokens, TokenKind.punctuation);
}

bool acceptIdentifier(ref TokenRange tokens, ref string spelling)
{
    return accept(tokens, spelling, TokenKind.identifier);
}

bool acceptStringLiteral(ref TokenRange tokens, ref string spelling)
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
    ref TokenRange tokens,
    bool[string] table)
    if (allSatisfy!(isStringValue, Ops))
{
    import std.traits;
    import std.range;

    auto local = tokens;

    ReturnType!parseChild[] exprs = [ parseChild(local, table) ];
    string[] ops = [];

    if (exprs[0] is null)
        return null;

    string op;
    while (accept!(Ops)(local, op, TokenKind.punctuation))
    {
        exprs ~= parseChild(local, table);

        if (exprs[$ - 1] is null)
            return null;

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

    return result;
}

struct ExprType
{
    enum Kind
    {
        unspecified,
        specified,
        generic,
    }

    bool lvalue = false;
    Kind kind;
    string spelling;

    this (Kind kind)
    {
        this.kind = kind;
    }

    this (string spelling)
    {
        this.kind = Kind.specified;
        this.spelling = spelling;
    }

    bool isUnspecified()
    {
        return kind == Kind.unspecified;
    }

    bool isSpecified()
    {
        return kind == Kind.specified;
    }

    bool isGeneric()
    {
        return kind == Kind.generic;
    }

    bool isLValue()
    {
        return lvalue;
    }

    ExprType asRValue()
    {
        ExprType clone = this;
        clone.lvalue = false;
        return clone;
    }

    ExprType asLValue()
    {
        ExprType clone = this;
        clone.lvalue = true;
        return clone;
    }

    ExprType decayed()
    {
        ExprType clone = this;
        clone.lvalue = false;
        clone.kind = clone.isGeneric ? Kind.unspecified : clone.kind;
        return clone;
    }
}

immutable UnspecifiedExprType = ExprType(ExprType.Kind.unspecified);

string asParamType(ExprType type)
{
    if (type.isSpecified)
        return type.isLValue ? "auto ref " ~ type.spelling : type.spelling;
    else
        return "auto ref T" ~ type.spelling;
}

string asPlainType(ExprType type)
{
    if (type.isSpecified)
        return type.spelling;
    else
        return "T" ~ type.spelling;
}

string asReturnType(ExprType type)
{
    final switch (type.kind)
    {
        case ExprType.Kind.unspecified: return "auto";
        case ExprType.Kind.specified: return type.spelling;
        case ExprType.Kind.generic: return "auto";
    }
}

ExprType strictCommonType(ExprType a, ExprType b)
{
    if (a == b)
        return a;
    else
        return ExprType(ExprType.kind.unspecified);
}

class Identifier : Expression
{
    this (string spelling)
    {
        this.spelling = spelling;
    }

    string spelling;

    override string translate(ref bool[string] imports)
    {
        return spelling;
    }

    override ExprType guessExprType()
    {
        return ExprType(ExprType.kind.unspecified);
    }

    override void guessParamTypes(ref ExprType[string] params, ExprType type)
    {
        auto param = spelling in params;

        if (param !is null && param.isUnspecified)
            *param = type;
    }

    override Expression braced()
    {
        return this;
    }

    override string toString()
    {
        import std.format : format;

        return format("Identifier(spelling = %s)", spelling);
    }
}

class Literal : Expression
{
    this (string spelling)
    {
        this.spelling = spelling;
    }

    string spelling;

    override string translate(ref bool[string] imports)
    {
        return spelling;
    }

    override ExprType guessExprType()
    {
        return ExprType("int");
    }

    override Expression braced()
    {
        return this;
    }

    override string toString()
    {
        import std.format : format;

        return format("Literal(spelling = %s)", spelling);
    }
}

class StringLiteral : Literal
{
    this (string spelling)
    {
        super(spelling);
    }
}

class StringifyExpr : Expression
{
    string spelling;

    this (string spelling)
    {
        this.spelling = spelling;
    }

    override string translate(ref bool[string] imports)
    {
        import std.format : format;

        imports["std.conv : to"] = true;

        return format("to!string(%s)", spelling);
    }

    override ExprType guessExprType()
    {
        return ExprType("string");
    }

    override string toString()
    {
        import std.format : format;

        return format("StringifyExpr(spelling = %s)", spelling);
    }
}

class StringConcat : Expression
{
    Expression[] substrings;

    this (Expression[] substrings)
    {
        this.substrings = substrings;
    }

    override string translate(ref bool[string] imports)
    {
        import std.algorithm.iteration : map;
        import std.array : join;

        return substrings.map!(a => a.translate(imports)).join(" ~ ");
    }

    override ExprType guessExprType()
    {
        return ExprType("string");
    }

    override string toString()
    {
        import std.format : format;

        return format("StringConcat(substrings = %s)", substrings);
    }
}

class StringsSequence : Expression
{
    StringLiteral[] literals;
}

class IndexExpr : Expression
{
    Expression subexpr;
    Expression index;

    override string translate(ref bool[string] imports)
    {
        import std.format : format;

        return format(
            "%s[%s]",
            subexpr.translate(imports),
            index.translate(imports));
    }

    override ExprType guessExprType()
    {
        return ExprType(ExprType.kind.unspecified);
    }

    override string toString()
    {
        import std.format : format;

        return format("IndexExpr(subexpr = %s, index = %s)", subexpr, index);
    }
}

class CallExpr : Expression
{
    Expression expr;
    Expression[] args;

    override string translate(ref bool[string] imports)
    {
        import std.algorithm.iteration : map;
        import std.format : format;
        import std.string : join;

        return format(
            "%s(%s)",
            expr.translate(imports),
            args.map!(a => a.translate(imports)).join(", "));
    }

    override ExprType guessExprType()
    {
        return ExprType(ExprType.kind.unspecified);
    }

    override string toString()
    {
        import std.format : format;

        return format("CallExpr(expr = %s, args = %s)", expr, args);
    }
}

class DotExpr : Expression
{
    Expression subexpr;
    string identifier;

    override string translate(ref bool[string] imports)
    {
        import std.format : format;
        import std.string : join;

        return format(
            "%s.%s",
            subexpr.translate(imports),
            identifier);
    }

    override ExprType guessExprType()
    {
        return ExprType(ExprType.kind.unspecified);
    }

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

class SubExpr : Expression
{
    Expression subexpr;

    this (Expression subexpr)
    {
        this.subexpr = subexpr;
    }

    override string translate(ref bool[string] imports)
    {
        import std.format : format;

        if (surplus)
            return format("%s", subexpr.translate(imports));
        else
            return format("(%s)", subexpr.translate(imports));
    }

    bool surplus() const
    {
        auto id = typeid(subexpr);
        return id == typeid(Identifier) || id == typeid(DotExpr);
    }

    override Expression debraced()
    {
        return subexpr.debraced;
    }

    override Expression braced()
    {
        return this;
    }

    override ExprType guessExprType()
    {
        return subexpr.guessExprType();
    }

    override void guessParamTypes(ref ExprType[string] params, ExprType type)
    {
        subexpr.guessParamTypes(params, type);
    }

    override string toString()
    {
        import std.format : format;

        return format("SubExpr(subexpr = %s)", subexpr);
    }
}

class UnaryExpr : Expression
{
    Expression subexpr;
    string operator;
    bool postfix = false;

    override string translate(ref bool[string] imports)
    {
        import std.format : format;

        if (operator == "sizeof")
            return format("%s.sizeof", subexpr.braced.translate(imports));
        else if (postfix)
            return format("%s%s", subexpr.translate(imports), operator);
        else
            return format("%s%s", operator, subexpr.translate(imports));
    }

    override ExprType guessExprType()
    {
        if (operator == "sizeof")
            return ExprType("size_t");
        else
            return subexpr.guessExprType();
    }

    override void guessParamTypes(ref ExprType[string] params, ExprType type)
    {
        if (operator == "sizeof")
            subexpr.guessParamTypes(params, UnspecifiedExprType);
        else if (operator == "++" || operator == "--")
            subexpr.guessParamTypes(params, type.asLValue);
        else
            subexpr.guessParamTypes(params, type);
    }

    override string toString()
    {
        import std.format : format;

        return format(
            "UnaryExpr(subexpr = %s, operator = %s)",
            subexpr,
            operator);
    }
}

class CastExpr : Expression
{
    string typename;
    Expression subexpr;

    override string translate(ref bool[string] imports)
    {
        import std.format : format;

        return format("cast(%s) %s", typename, subexpr.debraced.translate(imports));
    }

    override ExprType guessExprType()
    {
        return ExprType(typename);
    }

    override void guessParamTypes(ref ExprType[string] params, ExprType type)
    {
        subexpr.guessParamTypes(params, UnspecifiedExprType);
    }

    override string toString()
    {
        import std.format : format;

        return format(
            "CastExpr(typename = %s, subexpr = %s)",
            typename,
            subexpr);
    }
}

class BinaryExpr : Expression
{
    Expression left;
    Expression right;
    string operator;

    override string translate(ref bool[string] imports)
    {
        import std.format : format;

        return format(
            "%s %s %s",
            left.translate(imports),
            operator,
            right.translate(imports));
    }

    override ExprType guessExprType()
    {
        return strictCommonType(left.guessExprType(), right.guessExprType());
    }

    override void guessParamTypes(ref ExprType[string] params, ExprType type)
    {
        left.guessParamTypes(params, UnspecifiedExprType);
        right.guessParamTypes(params, UnspecifiedExprType);
    }

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

class CondExpr : Expression
{
    Expression expr;
    Expression left;
    Expression right;

    override string translate(ref bool[string] imports)
    {
        import std.format : format;

        return format(
            "%s ? %s : %s",
            expr.translate(imports),
            left.translate(imports),
            right.translate(imports));
    }

    override ExprType guessExprType()
    {
        return strictCommonType(left.guessExprType(), right.guessExprType());
    }

    override void guessParamTypes(ref ExprType[string] params, ExprType type)
    {
        expr.guessParamTypes(params, type);
        left.guessParamTypes(params, type);
        right.guessParamTypes(params, type);
    }

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

class Expression
{
    string translate()
    {
        bool[string] imports;
        return translate(imports);
    }

    string translate(ref bool[string] imports)
    {
        return "<" ~ toString ~ ">";
    }

    Expression debraced()
    {
        return this;
    }

    Expression braced()
    {
        return new SubExpr(this);
    }

    ExprType guessExprType()
    {
        return ExprType(ExprType.kind.generic);
    }

    void guessParamTypes(ref ExprType[string] params, ExprType type)
    { }

    override string toString()
    {
        return "";
    }

    void dumpAST(ref Appender!string result, size_t indent)
    {
        import std.format;
        import std.array : replicate;

        result.put(" ".replicate(indent));
        result.put(toString());
    }
}

class MacroDefinition
{
    string spelling;
    string[] params;
    bool constant;
    Expression expr;

    override string toString()
    {
        import std.format : format;

        return format(
            "MacroDefinition(spelling = %s, params = %s, constant = %s, expr = %s)",
            spelling,
            params,
            constant,
            expr);
    }

    void dumpAST(ref Appender!string result, size_t indent)
    {
        import std.format;
        import std.array : replicate;
        import std.string : join;

        result.put(" ".replicate(indent));

        if (constant)
            formattedWrite(result, "MacroDefinition %s", spelling);
        else
            formattedWrite(result, "MacroDefinition %s(%s)", spelling, join(params, ", "));

        if (expr !is null)
            expr.dumpAST(result, indent + 4);
    }

    string dumpAST()
    {
        auto result = Appender!string();
        dumpAST(result, 0);
        return result.data;
    }
}

Expression parseStringConcat(ref TokenRange tokens)
{
    import std.array;

    auto local = tokens;

    Expression[] substrings;

    while (true)
    {
        string spelling;

        if (acceptStringLiteral(local, spelling))
        {
            substrings ~= new StringLiteral(spelling);
        }
        else if (accept!("#")(local, TokenKind.punctuation))
        {
            if (!accept(local, spelling, TokenKind.identifier))
                return null;

            substrings ~= new StringifyExpr(spelling);
        }
        else
        {
            break;
        }
    }

    if (substrings.length == 0)
        return null;

    tokens = local;

    if (substrings.length == 1)
        return substrings.front;

    return new StringConcat(substrings);
}

Expression parsePrimaryExpr(ref TokenRange tokens, bool[string] table)
{
    string spelling;

    if (accept(tokens, spelling, TokenKind.identifier))
        return new Identifier(spelling);

    auto local = tokens;

    auto substrings = parseStringConcat(local);

    if (substrings !is null)
    {
        tokens = local;
        return substrings;
    }

    if (accept(local, spelling, TokenKind.literal))
    {
        tokens = local;
        return new Literal(spelling);
    }

    if (!accept!("(")(local, TokenKind.punctuation))
        return null;

    auto subexpr = parseExpr(local, table);

    if (subexpr is null)
        return null;

    if (!accept!(")")(local, TokenKind.punctuation))
        return null;

    tokens = local;

    return new SubExpr(subexpr);
}

Expression[] parseArgsList(ref TokenRange tokens, bool[string] table)
{
    auto local = tokens;

    Expression[] exprs = [ parseSftExpr(local, table) ];

    if (exprs[0] is null)
        return null;

    while (true)
    {
        if (acceptPunctuation!(",")(local))
        {
            Expression expr = parseSftExpr(local, table);

            if (expr is null)
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

Expression parsePostfixExp(ref TokenRange tokens, bool[string] table)
{
    auto local = tokens;

    Expression expr = parsePrimaryExpr(local, table);

    if (expr is null)
        return null;

    string spelling;

    while (true)
    {
        if (acceptPunctuation!("[")(local))
        {
            auto index = parseExpr(local, table);

            if (index is null)
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
                auto args = parseArgsList(local, table);

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

Expression parseUnaryExpr(ref TokenRange tokens, bool[string] table)
{
    auto local = tokens;

    string spelling;

    if (accept!("++", "--")(local, spelling, TokenKind.punctuation))
    {
        Expression subexpr = parseUnaryExpr(local, table);

        if (subexpr !is null)
        {
            UnaryExpr expr = new UnaryExpr;
            expr.subexpr = subexpr;
            expr.operator = spelling;
            tokens = local;
            return expr;
        }
    }

    if (accept!("&", "*", "+", "-", "~", "!")(local, spelling, TokenKind.punctuation))
    {
        Expression subexpr = parseCastExpr(local, table);

        if (subexpr !is null)
        {
            UnaryExpr expr = new UnaryExpr;
            expr.subexpr = subexpr;
            expr.operator = spelling;
            tokens = local;
            return expr;
        }
    }

    if (accept!("sizeof")(local, spelling, TokenKind.keyword))
    {
        Expression subexpr = parseUnaryExpr(local, table);

        if (subexpr !is null)
        {
            UnaryExpr expr = new UnaryExpr;
            expr.subexpr = subexpr;
            expr.operator = spelling;
            tokens = local;
            return expr;
        }

        // FIXME: unary-expression ::= sizeof ( type-name )
    }

    return parsePostfixExp(tokens, table);
}

Expression parseCastExpr(ref TokenRange tokens, bool[string] table)
{
    auto local = tokens;

    if (!accept!("(")(local, TokenKind.punctuation))
        return parseUnaryExpr(tokens, table);

    string typename;

    if (!accept(local, typename, TokenKind.identifier) &&
        !accept(local, typename, TokenKind.keyword))
        return parseUnaryExpr(tokens, table);
    else if ((typename in table) is null)
        return parseUnaryExpr(tokens, table);

    if (!accept!(")")(local, TokenKind.punctuation))
        return parseUnaryExpr(tokens, table);

    auto subexpr = parseCastExpr(local, table);

    if (subexpr is null)
        return parseUnaryExpr(tokens, table);

    tokens = local;

    CastExpr result = new CastExpr;
    result.typename = typename;
    result.subexpr = subexpr;

    return result;
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

Expression parseCondExpr(ref TokenRange tokens, bool[string] table)
{
    auto local = tokens;

    Expression expr = parseLogicalOrExpr(local, table);

    if (expr is null)
        return null;

    tokens = local;

    if (acceptPunctuation!("?")(local))
    {
        Expression left = parseExpr(local, table);

        if (left !is null && acceptPunctuation!(":")(local))
        {
            Expression right = parseCondExpr(local, table);

            if (right !is null)
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

Expression parseExpr(ref TokenRange tokens, bool[string] table)
{
    return parseCondExpr(tokens, table);
}

string[] parseMacroParams(ref TokenRange tokens)
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

MacroDefinition parseMacroDefinition(TokenRange tokens, bool[string] table)
{
    auto local = tokens;

    if (!accept!("#")(local, TokenKind.punctuation))
        return null;

    if (!accept!("define")(local, TokenKind.identifier))
        return null;

    MacroDefinition result = parsePartialMacroDefinition(local, table);

    if (result !is null)
        tokens = local;

    return result;
}

MacroDefinition parsePartialMacroDefinition(TokenRange tokens, bool[string] table)
{
    auto local = tokens;

    MacroDefinition result = new MacroDefinition;

    if (!accept(local, result.spelling, TokenKind.identifier))
        return null;

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
        result.constant = true;
    }

    result.expr = parseExpr(local, table);

    if (!local.empty)
        return null;
    else
        return result;
}

void translateConstDirective(Output output, MacroDefinition directive)
{
    output.singleLine(
        "enum %s = %s;",
        directive.spelling,
        directive.expr.debraced.translate());
}

string translateDirectiveParamList(string[] params, ExprType[string] types)
{
    import std.algorithm.iteration : map;
    import std.format : format;
    import std.array : join;

    return params.map!(a => format("%s %s", types[a].asParamType(), a)).join(", ");
}

string translateDirectiveTypeList(string[] params, ref ExprType[string] types)
{
    import std.algorithm.iteration : filter;
    import std.algorithm.searching : count;
    import std.format : format;
    import std.array : appender, join;

    bool canBeGeneric(ExprType type)
    {
        return type.isGeneric || type.isUnspecified;
    }

    auto filtered = params.filter!(a => canBeGeneric(types[a]));

    if (count(filtered) > 1)
    {
        size_t index = 0;
        foreach (param; filtered)
        {
            types[param].spelling = format("%s%d", types[param].spelling, index);
            ++index;
        }
    }

    auto result = appender!string;
    bool[ExprType] appended;

    if (!filtered.empty)
    {
        auto type = types[filtered.front];
        result.put(asPlainType(type));
        appended[type.decayed] = true;
        filtered.popFront();
    }

    foreach (param; filtered)
    {
        auto type = types[param];

        if ((type.decayed in appended) is null)
        {
            result.put(", ");
            result.put(asPlainType(type));
            appended[type.decayed] = true;
        }
    }

    return result.data;
}

bool translateFunctAlias(
    Output output,
    Context context,
    MacroDefinition definition)
{
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : map;

    CallExpr expr = cast(CallExpr) definition.expr;

    if (expr !is null)
    {
        Identifier ident = cast(Identifier) expr.expr;

        if (ident !is null &&
            equal(definition.params, expr.args.map!(a => a.translate)))
        {
            output.singleLine("alias %s = %s;", definition.spelling, ident.spelling);
            return true;
        }
    }

    return false;
}

void translateFunctDirective(
    Output output,
    Context context,
    MacroDefinition definition)
{
    import std.format : format;
    import std.array : join;

    if (translateFunctAlias(output, context, definition))
        return;

    ExprType returnType = definition.expr.guessExprType();
    string typeStrings = "", paramStrings = "";

    if (definition.params.length != 0)
    {
        ExprType[string] types;

        foreach (param; definition.params)
            types[param] = ExprType(ExprType.kind.unspecified);

        definition.expr.guessParamTypes(types, returnType);

        auto typeList = translateDirectiveTypeList(definition.params, types);

        if (typeList != "")
            typeStrings = format("(%s)", typeList);

        paramStrings = translateDirectiveParamList(definition.params, types);
    }

    bool[string] imports;

    auto translated = definition.expr.debraced.translate(imports);

    output.subscopeStrong(
        "%s%s %s%s(%s)",
        context.macroLinkagePrefix(),
        returnType.asReturnType(),
        definition.spelling,
        typeStrings,
        paramStrings) in {

        if (imports.length != 0)
        {
            foreach (item; imports.byKey)
                output.singleLine("import %s;", item);

            output.separator;
        }

        output.singleLine("return %s;", translated);
    };
}

void translateMacroDefinition(Output output, Context context, Cursor cursor)
{
    assert(cursor.kind == CXCursorKind.CXCursor_MacroDefinition);

    auto definition = parsePartialMacroDefinition(cursor.tokens, context.typeNames);

    if (definition !is null)
    {
        if (definition.expr !is null)
        {
            if (definition.constant)
                translateConstDirective(output, definition);
            else
                translateFunctDirective(output, context, definition);
        }

        context.macroDefinitions[definition.spelling] = definition;
    }
}
