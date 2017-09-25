/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 03, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.MacroDefinitionParser;

import std.array : Appender;
import std.traits;
import std.meta;

import clang.c.Index;
import clang.Cursor;
import clang.Util;
import clang.SourceLocation;
import clang.SourceRange;
import clang.Token;
import clang.Type;

import dstep.translator.Context;
import dstep.translator.Output;
import dstep.translator.Type;

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

    if (exprs[0] is null)
        return null;

    string op;
    while (accept!(Ops)(local, op, TokenKind.punctuation))
    {
        exprs ~= parseChild(local, table, defined);

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
        sizeOf
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
immutable SizeOfExprType = ExprType(ExprType.Kind.sizeOf);

string asParamType(ExprType type)
{
    if (type.isSpecified)
        return type.isLValue ? "auto ref " ~ type.spelling : type.spelling;
    else if (type.kind == ExprType.Kind.sizeOf)
        return "size_t";
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
        case ExprType.Kind.sizeOf: return "size_t";
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

    override string translate(Context context, Set!string params, ref Set!string imports)
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

    override string translate(Context context, Set!string params, ref Set!string imports)
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

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.format : format;

        imports.add("std.conv : to");

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

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.algorithm.iteration : map;
        import std.array : join;

        return substrings.map!(a => a.translate(context, params, imports)).join(" ~ ");
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

class TokenConcat : Expression
{
    Expression[] subexprs;

    this (Expression[] subexprs)
    {
        this.subexprs = subexprs;
    }

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.algorithm.iteration : map;
        import std.array : join;
        import std.format : format;

        string stringify(Expression subexpr)
        {
            auto identifier = cast(Identifier) subexpr;

            if (identifier && params.contains(identifier.spelling))
            {
                import std.format : format;

                imports.add("std.conv : to");

                return format("to!string(%s)", identifier.spelling);
            }
            else
            {
                return format(`"%s"`, subexpr.translate(context, params, imports));
            }
        }

        return subexprs.map!stringify.join(" ~ ");
    }

    override ExprType guessExprType()
    {
        return ExprType("string");
    }

    override string toString()
    {
        import std.format : format;

        return format("TokenConcat(subexprs = %s)", subexprs);
    }
}

class IndexExpr : Expression
{
    Expression subexpr;
    Expression index;

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.format : format;

        return format(
            "%s[%s]",
            subexpr.translate(context, params, imports),
            index.translate(context, params, imports));
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

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.algorithm.iteration : map;
        import std.format : format;
        import std.string : join;

        return format(
            "%s(%s)",
            expr.translate(context, params, imports),
            args.map!(a => a.translate(context, params, imports)).join(", "));
    }

    override ExprType guessExprType()
    {
        return ExprType(ExprType.kind.unspecified);
    }

    /*override void guessParamTypes(ref ExprType[string] params, ExprType type)
    {

    }*/

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

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.format : format;
        import std.string : join;

        return format(
            "%s.%s",
            subexpr.translate(context, params, imports),
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

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.format : format;

        if (surplus)
            return format("%s", subexpr.translate(context, params, imports));
        else
            return format("(%s)", subexpr.translate(context, params, imports));
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

    bool canHoistSizeOf(Context context)
    {
        return context.options.hoistSizeofInMacros
            && typeid(subexpr.debraced) == typeid(Identifier);
    }

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.format : format;

        if (operator == "sizeof")
            return format(
                "%s%s",
                subexpr.braced.translate(context, params, imports),
                canHoistSizeOf(context) ? "" : ".sizeof");
        else if (postfix)
            return format("%s%s", subexpr.translate(context, params, imports), operator);
        else
            return format("%s%s", operator, subexpr.translate(context, params, imports));
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

class DefinedExpr : Expression
{
    string identifier;

    override ExprType guessExprType()
    {
        return ExprType("int");
    }

    override string toString()
    {
        import std.format : format;

        return format("DefinedExpr(identifier = %s)", identifier);
    }
}

class SizeofType : Expression
{
    Type type;

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.format : format;

        return format("%s.sizeof", translateType(context, type));
    }

    override ExprType guessExprType()
    {
        return ExprType("size_t");
    }

    override string toString()
    {
        import std.format : format;

        return format("SizeofType(type = %s)", type);
    }
}

class CastExpr : Expression
{
    Type type;
    Expression subexpr;

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.format : format;

        return format(
            "cast(%s) %s",
            translateType(context, type),
            subexpr.debraced.translate(context, params, imports));
    }

    override ExprType guessExprType()
    {
        return UnspecifiedExprType;
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
            type,
            subexpr);
    }
}

class BinaryExpr : Expression
{
    Expression left;
    Expression right;
    string operator;

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.format : format;

        return format(
            "%s %s %s",
            left.translate(context, params, imports),
            operator,
            right.translate(context, params, imports));
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

    override string translate(Context context, Set!string params, ref Set!string imports)
    {
        import std.format : format;

        return format(
            "%s ? %s : %s",
            expr.translate(context, params, imports),
            left.translate(context, params, imports),
            right.translate(context, params, imports));
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
    protected static string translateType(Context context, Type type)
    {
        return dstep.translator.Type.translateType(context, Cursor.init, type);
    }

    string translate(Context context, Set!string params, ref Set!string imports)
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

enum DirectiveKind
{
    elif,
    else_,
    endif,
    error,
    define,
    if_,
    ifdef,
    ifndef,
    include,
    line,
    undef,
    pragmaOnce,
}

bool isIf(DirectiveKind kind)
{
    return kind == DirectiveKind.if_ ||
        kind == DirectiveKind.ifdef ||
        kind == DirectiveKind.ifndef;
}

class Directive
{
    Token[] tokens;
    SourceRange extent;
    DirectiveKind kind;

    @property SourceLocation location()
    {
        return extent.start;
    }

    override string toString()
    {
        import std.format : format;
        return format("Directive(kind = %s)", kind);
    }
}

class MacroDefinition : Directive
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

Expression parseTokenConcat(ref Token[] tokens)
{
    Expression parseSubexpr(ref Token[] tokens)
    {
        string spelling;

        if (acceptIdentifier(tokens, spelling))
            return new Identifier(spelling);

        if (acceptLiteral(tokens, spelling))
            return new Literal(spelling);

        return null;
    }

    auto local = tokens;

    Expression[] subexprs;

    if (auto first = parseSubexpr(local))
    {
        if (!acceptPunctuation!("##")(local))
            return null;

        if (auto expr = parseSubexpr(local))
        {
            subexprs ~= first;
            subexprs ~= expr;

            tokens = local;

            while (acceptPunctuation!("##")(local))
            {
                expr = parseSubexpr(local);

                if (expr)
                {
                    subexprs ~= expr;
                    tokens = local;
                }
                else
                {
                    break;
                }
            }

            return new TokenConcat(subexprs);
        }
    }

    return null;
}

Expression parsePrimaryExpr(ref Token[] tokens, Cursor[string] table, bool defined)
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

    auto subexpr = parseExpr(local, table, defined);

    if (subexpr is null)
        return null;

    if (!accept!(")")(local, TokenKind.punctuation))
        return null;

    tokens = local;

    return new SubExpr(subexpr);
}

Expression[] parseArgsList(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto local = tokens;

    Expression[] exprs = [ parseSftExpr(local, table, defined) ];

    if (exprs[0] is null)
        return null;

    while (true)
    {
        if (acceptPunctuation!(",")(local))
        {
            Expression expr = parseSftExpr(local, table, defined);

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

Expression parsePostfixExpr(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto local = tokens;

    Expression expr = parsePrimaryExpr(local, table, defined);

    if (expr is null)
        return null;

    string spelling;

    while (true)
    {
        if (acceptPunctuation!("[")(local))
        {
            auto index = parseExpr(local, table, defined);

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
            SizeofType expr = new SizeofType;
            expr.type = type;
            tokens = local;
            return expr;
        }
    }

    return null;
}

Expression parseDefinedExpr(ref Token[] tokens)
{
    auto local = tokens;

    if (accept!("defined")(local, TokenKind.identifier))
    {
        string spelling;

        if (acceptIdentifier(local, spelling))
        {
            auto expr = new DefinedExpr;
            expr.identifier = spelling;
            tokens = local;
            return expr;
        }

        if (acceptPunctuation!("(")(local) &&
            acceptIdentifier(local, spelling) &&
            acceptPunctuation!(")")(local))
        {
            auto expr = new DefinedExpr;
            expr.identifier = spelling;
            tokens = local;
            return expr;
        }
    }

    return null;
}

Expression parseUnaryExpr(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto local = tokens;

    string spelling;

    if (accept!("++", "--")(local, spelling, TokenKind.punctuation))
    {
        Expression subexpr = parseUnaryExpr(local, table, defined);

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
        Expression subexpr = parseCastExpr(local, table, defined);

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
        if (auto expr = parseSizeofType(local, table))
        {
            tokens = local;
            return expr;
        }

        Expression subexpr = parseUnaryExpr(local, table, defined);

        if (subexpr !is null)
        {
            UnaryExpr expr = new UnaryExpr;
            expr.subexpr = subexpr;
            expr.operator = spelling;
            tokens = local;
            return expr;
        }
    }

    if (defined)
    {
        auto expr = parseDefinedExpr(local);

        if (expr)
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

    if (subexpr is null)
        return parseUnaryExpr(tokens, table, defined);

    tokens = local;

    CastExpr result = new CastExpr;
    result.type = type;
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

Expression parseCondExpr(ref Token[] tokens, Cursor[string] table, bool defined)
{
    auto local = tokens;

    Expression expr = parseLogicalOrExpr(local, table, defined);

    if (expr is null)
        return null;

    tokens = local;

    if (acceptPunctuation!("?")(local))
    {
        Expression left = parseExpr(local, table, defined);

        if (left !is null && acceptPunctuation!(":")(local))
        {
            Expression right = parseCondExpr(local, table, defined);

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
    if (auto expr = parseTokenConcat(tokens))
        return expr;

    if (auto expr = parseCondExpr(tokens, table, defined))
        return expr;

    return null;
}

Expression parseExpr(ref Token[] tokens, bool defined)
{
    Cursor[string] table;

    return parseCondExpr(tokens, table, defined);
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
        result.constant = true;
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
