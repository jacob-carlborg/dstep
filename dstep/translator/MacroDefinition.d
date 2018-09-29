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
import dstep.translator.TypeInference;

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

struct ExpressionContext
{
    Context context;
    Set!string params;
    Set!string* imports;
    Cursor scope_;
    alias context this;

    @disable this();

    private this (int x) { }

    static ExpressionContext make()
    {
        struct AA { Set!string aa; }
        auto result = ExpressionContext(0);
        result.imports = &(new AA()).aa;
        return result;
    }

    static ExpressionContext make(Context context)
    {
        auto result = ExpressionContext.make();
        result.context = context;
        return result;
    }

    static ExpressionContext make(Context context, Set!string params)
    {
        auto result = ExpressionContext.make(context);
        result.params = params;
        return result;
    }
}

string translate(Identifier identifier, ExpressionContext context)
{
    context.resolveMacroDependency(identifier.spelling);

    auto constant = identifier.spelling in context.constNames();

    if (constant !is null)
    {
        if (constant.kind == CXCursorKind.enumConstantDecl)
        {
            auto typedefParent = context.typedefParent(constant.lexicalParent);
            auto lexicalParent = constant.lexicalParent;

            auto scopeName = typedefParent
                ? typedefParent.spelling
                : lexicalParent.spelling;

            auto scopePrefix = lexicalParent != context.scope_
                ? scopeName ~ "."
                : "";

            return scopePrefix ~ context.translateSpelling(*constant);
        }
    }

    return identifier.spelling;
}

string translate(CallExpr expression, ExpressionContext context)
{
    import std.algorithm;
    import std.format;
    import std.range;
    import std.string;

    auto spelling = expression.expr.spelling;

    alias fmap = a => a.debraced.translate(context);

    if (spelling !is null)
    {
        context.resolveMacroDependency(spelling);

        auto definition = spelling in context.translator.typedMacroDefinitions;

        if (definition !is null)
        {
            string[] typeArguments, valueArguments;

            auto arguments = zip(
                definition.signature.params,
                expression.args.map!fmap);

            foreach (type, argument; arguments) {
                if (auto defined = type.peek!Meta)
                    typeArguments ~= argument;
                else
                    valueArguments ~= argument;
            }

            string typesList = typeArguments.length <= 1
                ? typeArguments.join(", ")
                : "(" ~ typeArguments.join(", ") ~ ")";

            string argumentList = "(" ~ valueArguments.join(", ") ~ ")";

            string exclamation = typesList.empty ? "" : "!";

            return spelling ~ exclamation ~ typesList ~ argumentList;
        }
    }

    return format(
        "%s(%s)",
        expression.expr.translate(context),
        expression.args.map!fmap.join(", "));
}

string translate(Expression expression, ExpressionContext context)
{
    import std.format : format;

    if (!expression.hasValue)
        return null;

    string translateBinaryOperator(T)(T operator)
    {
        return format(
            "%s %s %s",
            operator.left.translate(context),
            operator.operator,
            operator.right.translate(context));
    }

    return expression.visit!(
        delegate string(Identifier identifier)
        {
            return identifier.translate(context);
        },
        delegate string(TypeIdentifier identifier)
        {
            auto spelling = translateType(context, Cursor.init, identifier.type)
                .makeString();
            context.resolveMacroDependency(spelling);
            return spelling;
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
            (*context.imports).add("std.conv : to");
            return format("to!string(%s)", stringifyExpr.spelling);
        },
        delegate string(StringConcat stringConcat)
        {
            import std.algorithm.iteration : map;
            import std.array : join;

            return stringConcat.substrings
                .map!(a => a.translate(context)).join(" ~ ");
        },
        delegate string(TokenConcat tokenConcat)
        {
            import std.algorithm.iteration : map;
            import std.array : join;

            string stringify(Expression subexpr)
            {
                auto identifier = subexpr.peek!Identifier;

                if (identifier !is null &&
                    context.params.contains(identifier.spelling))
                {
                    import std.format : format;

                    (*context.imports).add("std.conv : to");

                    return format("to!string(%s)", identifier.spelling);
                }
                else
                {
                    auto translated = subexpr.translate(context);

                    return format(`"%s"`, translated);
                }
            }

            return tokenConcat.subexprs.map!stringify.join(" ~ ");
        },
        delegate string(IndexExpr indexExpr)
        {
            return format(
                "%s[%s]",
                indexExpr.subexpr.translate(context),
                indexExpr.index.translate(context));
        },
        delegate string(CallExpr callExpr)
        {
            return callExpr.translate(context);
        },
        delegate string(DotExpr dotExpr)
        {
            return format(
                "%s.%s",
                dotExpr.subexpr.translate(context),
                dotExpr.identifier);
        },
        delegate string(ArrowExpr arrowExpr)
        {
            return format(
                "%s.%s",
                arrowExpr.subexpr.translate(context),
                arrowExpr.identifier);
        },
        delegate string(SubExpr subExpr)
        {
            auto surplus = subExpr.subexpr.peek!Identifier !is null
                || subExpr.subexpr.peek!DotExpr !is null;

            string translated = subExpr.subexpr.translate(context);

            return surplus ? translated : "(" ~ translated ~ ")";
        },
        delegate string(UnaryExpr unaryExpr)
        {
            if (unaryExpr.operator == "sizeof")
                return format(
                    "%s.sizeof",
                    unaryExpr.subexpr.braced.translate(context));
            else if (unaryExpr.postfix)
                return format(
                    "%s%s",
                    unaryExpr.subexpr.translate(context),
                    unaryExpr.operator);
            else
                return format(
                    "%s%s",
                    unaryExpr.operator,
                    unaryExpr.subexpr.translate(context));
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
                castExpr.subexpr.debraced.translate(context));
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
                condExpr.expr.translate(context),
                condExpr.left.translate(context),
                condExpr.right.translate(context));
        });
}

void guessParamTypes(Expression expression, ref ExprType[string] params, ExprType type)
{
    import std.format : format;

    if (!expression.hasValue)
        return;

    void pass(T)(T operator) { }

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
        },
        pass);
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

bool translateFunctAlias(
    Output output,
    Context context,
    MacroDefinition definition)
{
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : map;

    CallExpr* expr = definition.expr.peek!CallExpr;
    auto expressionContext = ExpressionContext.make(context);

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
            equal(definition.params, expr.args
                .map!(a => a.translate(expressionContext))))
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

string spelling(CallExpr expression)
{
    auto identifier = expression.expr.debraced.peek!Identifier();
    return identifier is null ? null : identifier.spelling;
}

string spelling(Expression expression)
{
    auto debraced = expression.debraced();

    if (!debraced.hasValue)
        return null;

    auto identifier = debraced.peek!Identifier();

    if (identifier is null)
        return null;

    return identifier.spelling;
}

void translateMacroDefinitionAliasOrConst(
    Output output,
    Context context,
    TypedMacroDefinition definition)
{
    auto expressionContext = ExpressionContext.make(context);

    string formatString;
    auto debraced = definition.definition.expr.debraced;

    if (debraced.peek!TypeIdentifier)
    {
        version (D1)
            formatString = "alias %2$s %1$s;";
        else
            formatString = "alias %s = %s;";
    }
    else
    {
        version (D1)
            formatString = "const %s = %s;";
        else
            formatString = "enum %s = %s;";
    }

    output.singleLine(
        formatString,
        definition.definition.spelling,
        debraced.translate(expressionContext));
}

void translateMacroDefinition(
    Output output,
    Context context,
    TypedMacroDefinition definition)
{
    import std.algorithm;
    import std.conv;
    import std.range;

    if (definition.aliasOrConst)
    {
        translateMacroDefinitionAliasOrConst(output, context, definition);
    }
    else if (!translateFunctAlias(output, context, definition))
    {
        string[] typeParams, paramTypes, variables;

        auto params = zip(
            definition.signature.params,
            definition.params,
            iota(definition.params.length));

        auto numTypes = definition.signature.params
            .count!(x => x.peek!Generic !is null);

        foreach (type, name, index; params) {
            if (auto defined = type.peek!Defined)
            {
                variables ~= defined.spelling ~ " " ~ name;
            }
            else if (type.peek!Generic)
            {
                paramTypes ~= numTypes == 1 ? "T" : "T" ~ index.to!string();
                variables ~= "auto ref " ~ paramTypes.back ~ " " ~ name;
            }
            else
            {
                typeParams ~= name;
            }
        }

        auto types = typeParams ~ paramTypes;

        auto expressionContext = ExpressionContext.make(
            context,
            setFromList(definition.params));

        auto translated = definition.expr.debraced.translate(expressionContext);

        auto resultType = definition.signature.result;

        output.subscopeStrong(
            "extern (D) %s %s%s(%s)",
            resultType.peek!Defined ? resultType.get!Defined.spelling : "auto",
            definition.spelling,
            types.empty ? "" : "(" ~ types.join(", ") ~ ")",
            variables.join(", "))
        in {
            if (expressionContext.imports.length != 0)
            {
                foreach (item; expressionContext.imports.byKey)
                    output.singleLine("import %s;", item);

                output.separator;
            }

            output.singleLine("return %s;", translated);
        };
    }
}

string translateMacroDefinition(Context context, TypedMacroDefinition definition)
{
    Output output = new Output();
    translateMacroDefinition(output, context, definition);
    return output.data;
}
