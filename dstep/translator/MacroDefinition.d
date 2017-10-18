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
import std.variant;

import clang.c.Index;
import clang.Cursor;
import clang.Util;
import clang.SourceLocation;
import clang.SourceRange;
import clang.Token;
import clang.Type;

import dstep.translator.Context;
import dstep.translator.MacroParser;
import dstep.translator.Output;
import dstep.translator.Type;

void dumpAST(Expression expression, ref Appender!string result, size_t indent)
{
    import std.format;
    import std.array : replicate;

    result.put(" ".replicate(indent));
    result.put(expression.toString());
}

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

void resolveMacroDependency(Context context, string spelling)
{
    auto cursor = spelling in context.macroIndex.globalCursors();

    if (cursor !is null)
        return context.includeHandler.resolveDependency(*cursor);
}

string translate(Expression expression, Context context, Set!string params, ref Set!string imports)
{
    import std.format : format;

    if (!expression.hasValue)
        return null;

    string translateBinaryOperator(T)(T operator)
    {
        return format(
            "%s %s %s",
            operator.left.translate(context, params, imports),
            operator.operator,
            operator.right.translate(context, params, imports));
    }

    return expression.visit!(
        delegate string(Identifier identifier)
        {
            context.resolveMacroDependency(identifier.spelling);
            return identifier.spelling;
        },
        delegate string(Literal literal)
        {
            return literal.spelling;
        },
        delegate string(StringLiteral stringLiteral)
        {
            return stringLiteral.spelling;
        },
        delegate string(StringifyExpr stringifyExpr)
        {
            imports.add("std.conv : to");
            return format("to!string(%s)", stringifyExpr.spelling);
        },
        delegate string(StringConcat stringConcat)
        {
            import std.algorithm.iteration : map;
            import std.array : join;

            return stringConcat.substrings
                .map!(a => a.translate(context, params, imports)).join(" ~ ");
        },
        delegate string(TokenConcat tokenConcat)
        {
            import std.algorithm.iteration : map;
            import std.array : join;

            string stringify(Expression subexpr)
            {
                auto identifier = subexpr.peek!Identifier;

                if (identifier !is null && params.contains(identifier.spelling))
                {
                    import std.format : format;

                    imports.add("std.conv : to");

                    return format("to!string(%s)", identifier.spelling);
                }
                else
                {
                    auto translated = subexpr.translate(
                        context,
                        params,
                        imports);

                    return format(`"%s"`, translated);
                }
            }

            return tokenConcat.subexprs.map!stringify.join(" ~ ");
        },
        delegate string(IndexExpr indexExpr)
        {
            return format(
                "%s[%s]",
                indexExpr.subexpr.translate(context, params, imports),
                indexExpr.index.translate(context, params, imports));
        },
        delegate string(CallExpr callExpr)
        {
            import std.algorithm.iteration : map;
            import std.string : join;

            alias translate = a => a.translate(context, params, imports);

            return format(
                "%s(%s)",
                callExpr.expr.translate(context, params, imports),
                callExpr.args.map!translate.join(", "));
        },
        delegate string(DotExpr dotExpr)
        {
            return format(
                "%s.%s",
                dotExpr.subexpr.translate(context, params, imports),
                dotExpr.identifier);
        },
        delegate string(ArrowExpr arrowExpr)
        {
            return format(
                "%s.%s",
                arrowExpr.subexpr.translate(context, params, imports),
                arrowExpr.identifier);
        },
        delegate string(SubExpr subExpr)
        {
            auto surplus = subExpr.subexpr.peek!Identifier !is null
                || subExpr.subexpr.peek!DotExpr !is null;

            string translated = subExpr.subexpr.translate(
                context,
                params,
                imports);

            return surplus ? translated : "(" ~ translated ~ ")";
        },
        delegate string(UnaryExpr unaryExpr)
        {
            if (unaryExpr.operator == "sizeof")
                return format(
                    "%s.sizeof",
                    unaryExpr.subexpr.braced.translate(context, params, imports));
            else if (unaryExpr.postfix)
                return format(
                    "%s%s",
                    unaryExpr.subexpr.translate(context, params, imports),
                    unaryExpr.operator);
            else
                return format(
                    "%s%s",
                    unaryExpr.operator,
                    unaryExpr.subexpr.translate(context, params, imports));
        },
        delegate string(DefinedExpr literal)
        {
            return "";
        },
        delegate string(SizeofType sizeofType)
        {
            return format(
                "%s.sizeof",
                translateType(context, Cursor.init, sizeofType.type).makeString());
        },
        delegate string(CastExpr castExpr)
        {
            return format(
                "cast(%s) %s",
                translateType(context, Cursor.init, castExpr.type).makeString(),
                castExpr.subexpr.debraced.translate(context, params, imports));
        },
        translateBinaryOperator!MulExpr,
        translateBinaryOperator!AddExpr,
        translateBinaryOperator!SftExpr,
        translateBinaryOperator!RelExpr,
        translateBinaryOperator!EqlExpr,
        translateBinaryOperator!AndExpr,
        translateBinaryOperator!XorExpr,
        translateBinaryOperator!OrExpr,
        translateBinaryOperator!LogicalAndExpr,
        translateBinaryOperator!LogicalOrExpr,
        delegate string(CondExpr condExpr)
        {
            return format(
                "%s ? %s : %s",
                condExpr.expr.translate(context, params, imports),
                condExpr.left.translate(context, params, imports),
                condExpr.right.translate(context, params, imports));
        });
}

ExprType guessExprType(Expression expression)
{
    import std.format : format;

    if (!expression.hasValue)
        return ExprType(ExprType.kind.unspecified);

    ExprType guessBinaryOperator(T)(T operator)
    {
        return strictCommonType(
            operator.left.guessExprType(),
            operator.right.guessExprType());
    }

    return expression.visit!(
        delegate ExprType(Identifier identifier)
        {
            return ExprType(ExprType.kind.unspecified);
        },
        delegate ExprType(Literal literal)
        {
            return ExprType("int");
        },
        delegate ExprType(StringLiteral stringLiteral)
        {
            return ExprType("string");
        },
        delegate ExprType(StringifyExpr stringifyExpr)
        {
            return ExprType("string");
        },
        delegate ExprType(StringConcat stringConcat)
        {
            return ExprType("string");
        },
        delegate ExprType(TokenConcat tokenConcat)
        {
            return ExprType("string");
        },
        delegate ExprType(IndexExpr indexExpr)
        {
            return ExprType(ExprType.kind.unspecified);
        },
        delegate ExprType(CallExpr callExpr)
        {
            return ExprType(ExprType.kind.unspecified);
        },
        delegate ExprType(DotExpr dotExpr)
        {
            return ExprType(ExprType.kind.unspecified);
        },
        delegate ExprType(ArrowExpr arrowExpr)
        {
            return ExprType(ExprType.kind.unspecified);
        },
        delegate ExprType(SubExpr subExpr)
        {
            return subExpr.subexpr.guessExprType();
        },
        delegate ExprType(UnaryExpr unaryExpr)
        {
            if (unaryExpr.operator == "sizeof")
                return ExprType("size_t");
            else
                return unaryExpr.subexpr.guessExprType();
        },
        delegate ExprType(DefinedExpr literal)
        {
            return ExprType("int");
        },
        delegate ExprType(SizeofType sizeofType)
        {
            return ExprType("size_t");
        },
        delegate ExprType(CastExpr castExpr)
        {
            return UnspecifiedExprType;
        },
        guessBinaryOperator!MulExpr,
        guessBinaryOperator!AddExpr,
        guessBinaryOperator!SftExpr,
        guessBinaryOperator!RelExpr,
        guessBinaryOperator!EqlExpr,
        guessBinaryOperator!AndExpr,
        guessBinaryOperator!XorExpr,
        guessBinaryOperator!OrExpr,
        guessBinaryOperator!LogicalAndExpr,
        guessBinaryOperator!LogicalOrExpr,
        delegate ExprType(CondExpr condExpr)
        {
            return strictCommonType(
                condExpr.left.guessExprType(),
                condExpr.right.guessExprType());
        });
}

void guessParamTypes(Expression expression, ref ExprType[string] params, ExprType type)
{
    import std.format : format;

    if (!expression.hasValue)
        return;

    void noop(T)(T operator)
    {
    }

    void guessBinaryOperator(T)(T operator)
    {
        operator.left.guessParamTypes(params, UnspecifiedExprType);
        operator.right.guessParamTypes(params, UnspecifiedExprType);
    }

    return expression.visit!(
        delegate void(Identifier identifier)
        {
            auto param = identifier.spelling in params;

            if (param !is null && param.isUnspecified)
                *param = type;
        },
        noop!Literal,
        noop!StringLiteral,
        noop!StringifyExpr,
        noop!StringConcat,
        noop!TokenConcat,
        noop!IndexExpr,
        noop!CallExpr,
        noop!DotExpr,
        noop!ArrowExpr,
        delegate void(SubExpr subExpr)
        {
            subExpr.subexpr.guessParamTypes(params, type);
        },
        delegate void(UnaryExpr unaryExpr)
        {
            if (unaryExpr.operator == "sizeof")
                unaryExpr.subexpr.guessParamTypes(params, UnspecifiedExprType);
            else if (unaryExpr.operator == "++" || unaryExpr.operator == "--")
                unaryExpr.subexpr.guessParamTypes(params, type.asLValue);
            else
                unaryExpr.subexpr.guessParamTypes(params, type);
        },
        noop!DefinedExpr,
        noop!SizeofType,
        delegate void(CastExpr castExpr)
        {
            castExpr.subexpr.guessParamTypes(params, UnspecifiedExprType);
        },
        guessBinaryOperator!MulExpr,
        guessBinaryOperator!AddExpr,
        guessBinaryOperator!SftExpr,
        guessBinaryOperator!RelExpr,
        guessBinaryOperator!EqlExpr,
        guessBinaryOperator!AndExpr,
        guessBinaryOperator!XorExpr,
        guessBinaryOperator!OrExpr,
        guessBinaryOperator!LogicalAndExpr,
        guessBinaryOperator!LogicalOrExpr,
        delegate void(CondExpr condExpr)
        {
            condExpr.expr.guessParamTypes(params, type);
            condExpr.left.guessParamTypes(params, type);
            condExpr.right.guessParamTypes(params, type);
        });
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

        if (expr.hasValue)
            expr.dumpAST(result, indent + 4);
    }

    string dumpAST()
    {
        auto result = Appender!string();
        dumpAST(result, 0);
        return result.data;
    }
}

void translateConstDirective(
    Output output,
    Context context,
    MacroDefinition directive)
{
    Set!string params, imports;

    version (D1)
        enum fmt = "const %s = %s;";
    else
        enum fmt = "enum %s = %s;";

    output.singleLine(
        fmt,
        directive.spelling,
        directive.expr.debraced.translate(context, params, imports));
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
    Set!ExprType appended;

    if (!filtered.empty)
    {
        auto type = types[filtered.front];
        result.put(asPlainType(type));
        appended.add(type.decayed);
        filtered.popFront();
    }

    foreach (param; filtered)
    {
        auto type = types[param];

        if (!appended.contains(type.decayed))
        {
            result.put(", ");
            result.put(asPlainType(type));
            appended.add(type.decayed);
        }
    }

    return result.data;
}

bool translateFunctAlias(
    Output output,
    Context context,
    MacroDefinition definition,
    Set!string params)
{
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : map;

    CallExpr* expr = definition.expr.peek!CallExpr;
    Set!string imports;

    if (expr !is null)
    {
        Identifier* ident = expr.expr.peek!Identifier;

        if (ident.spelling == "assert")
        {
            // aliasing `assert` from C "assert.h" is commong enough to warrant
            // a special case to use function instead of an alias
            output.singleLine("void %s(T...)(T args)", definition.spelling);
            version (D1)
            {
                // does not support template constraints
            }
            else
            {
                output.singleLine("    if (T.length <= 2)");
            }
            output.singleLine("{");
            output.singleLine("    assert(args);");
            output.singleLine("}");
            return true;
        }

        if (ident !is null &&
            equal(definition.params, expr.args.map!(a => a.translate(context, params, imports))))
        {
            version (D1)
                enum fmt = "alias %2$s %1$s;";
            else
                enum fmt = "alias %1$s = %2$s;";

            output.singleLine(fmt, definition.spelling, ident.spelling);
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

    Set!string params;

    if (translateFunctAlias(output, context, definition, params))
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

        foreach (param; types.byKey)
            params.add(param);
    }

    Set!string imports;

    auto translated = definition.expr.debraced.translate(context, params, imports);

    output.subscopeStrong(
        "%s%s %s%s(%s)",
        "extern (D) ",
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
    assert(cursor.kind == CXCursorKind.macroDefinition);

    auto tokens = cursor.tokens;

    auto definition = parsePartialMacroDefinition(tokens, context.typeNames);

    if (definition !is null)
    {
        if (definition.expr.hasValue)
        {
            if (definition.constant)
                translateConstDirective(output, context, definition);
            else
                translateFunctDirective(output, context, definition);
        }
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
