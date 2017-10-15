/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: October 13, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.TypeInference;

import std.container.dlist;
import std.range;
import std.traits;
import std.variant;

import clang.c.Index;
import clang.Cursor;
import clang.SourceLocation;
import clang.SourceRange;
import clang.Token;
import clang.TranslationUnit;

import dstep.translator.Context;
import dstep.translator.MacroParser;
import dstep.translator.Preprocessor;

struct Defined
{
    string spelling;
}

struct Generic
{
}

struct Meta
{
}

alias InferredType = Algebraic!(Defined, Generic, Meta);

struct InferredSignature
{
    InferredType result;
    InferredType[] params;

    static InferredSignature fromDefinition(MacroDefinition definition)
    {
        import std.array;
        import std.range;

        return InferredSignature(
            InferredType(Generic.init),
            repeat(InferredType(Generic.init), definition.params.length).array);
    }
}

void inferMacroSignature(
    InferenceContext context,
    TypedMacroDefinition currentDefinition)
{
    inferMacroSignature(context, currentDefinition, currentDefinition.expr);
}

void inferMacroSignature(
    InferenceContext context,
    TypedMacroDefinition currentDefinition,
    Expression expression)
{
    if (!expression.hasValue)
        return;

    void pass(T)(T operator) { }

    bool isParamMeta(TypedMacroDefinition definition, string name)
    {
        import std.algorithm;
        ptrdiff_t index = definition.params.countUntil(name);
        return index != -1 && definition.signature.params[index].peek!Meta;
    }

    return expression.visit!(
        delegate void(CallExpr expression)
        {
            auto spelling = expression.spelling;

            if (spelling is null)
                return;

            auto definition = spelling in context.definitions;

            if (definition is null)
                return;

            auto updated = false;

            foreach (index, argument; expression.args)
            {
                if (auto argumentIdentifier
                    = argument.debraced.peek!Identifier)
                {
                    if (isParamMeta(currentDefinition, argument.spelling) &&
                        definition.signature.params[index].peek!Generic)
                    {
                        definition.signature.params[index] = Meta.init;
                        updated = true;
                    }
                }
                else if (auto argumentIdentifier
                    = argument.debraced.peek!TypeIdentifier)
                {
                    if (definition.signature.params[index].peek!Generic)
                    {
                        definition.signature.params[index] = Meta.init;
                        updated = true;
                    }
                }
                else
                {
                    inferMacroSignature(context, currentDefinition, argument);
                }
            }

            if (updated)
                context.queue.insertBack(*definition);
        },
        delegate void(SubExpr subExpr)
        {
            inferMacroSignature(context, currentDefinition, subExpr.subexpr);
        },
        pass);
}

InferredType commonType(InferredType a, InferredType b)
{
    if (a == b)
        return a;
    else
        return InferredType(Generic.init);
}

InferredType inferExpressionType(Expression expression)
{
    import std.format : format;

    if (!expression.hasValue)
        return InferredType.init;

    InferredType inferBinaryOperator(T)(T operator)
    {
        return commonType(
            operator.left.inferExpressionType(),
            operator.right.inferExpressionType());
    }

    return expression.visit!(
        delegate InferredType(Identifier identifier)
        {
            return InferredType(Generic.init);
        },
        delegate InferredType(TypeIdentifier identifier)
        {
            return InferredType(Meta.init);
        },
        delegate InferredType(Literal literal)
        {
            return InferredType(Defined("int"));
        },
        delegate InferredType(StringLiteral stringLiteral)
        {
            return InferredType(Defined("string"));
        },
        delegate InferredType(StringifyExpr stringifyExpr)
        {
            return InferredType(Defined("string"));
        },
        delegate InferredType(StringConcat stringConcat)
        {
            return InferredType(Defined("string"));
        },
        delegate InferredType(TokenConcat tokenConcat)
        {
            return InferredType(Defined("string"));
        },
        delegate InferredType(IndexExpr indexExpr)
        {
            return InferredType(Generic.init);
        },
        delegate InferredType(CallExpr callExpr)
        {
            return InferredType(Generic.init);
        },
        delegate InferredType(DotExpr dotExpr)
        {
            return InferredType(Generic.init);
        },
        delegate InferredType(ArrowExpr arrowExpr)
        {
            return InferredType(Generic.init);
        },
        delegate InferredType(SubExpr subExpr)
        {
            return subExpr.subexpr.inferExpressionType();
        },
        delegate InferredType(UnaryExpr unaryExpr)
        {
            if (unaryExpr.operator == "sizeof")
                return InferredType(Defined("size_t"));
            else
                return unaryExpr.subexpr.inferExpressionType();
        },
        delegate InferredType(DefinedExpr literal)
        {
            return InferredType(Defined("int"));
        },
        delegate InferredType(SizeofType sizeofType)
        {
            return InferredType(Defined("size_t"));
        },
        delegate InferredType(CastExpr castExpr)
        {
            return InferredType(Generic.init);
        },
        inferBinaryOperator!MulExpr,
        inferBinaryOperator!AddExpr,
        inferBinaryOperator!SftExpr,
        inferBinaryOperator!RelExpr,
        inferBinaryOperator!EqlExpr,
        inferBinaryOperator!AndExpr,
        inferBinaryOperator!XorExpr,
        inferBinaryOperator!OrExpr,
        inferBinaryOperator!LogicalAndExpr,
        inferBinaryOperator!LogicalOrExpr,
        delegate InferredType(CondExpr condExpr)
        {
            return commonType(
                condExpr.left.inferExpressionType(),
                condExpr.right.inferExpressionType());
        });
}

class InferenceContext
{
    Cursor[string] globalTypes;
    DList!TypedMacroDefinition queue;
    TypedMacroDefinition[string] definitions;
}

class TypedMacroDefinition
{
    MacroDefinition definition;
    InferredSignature signature;
    alias definition this;

    static TypedMacroDefinition fromDefinition(MacroDefinition definition)
    {
        auto result = new TypedMacroDefinition();
        result.definition = definition;
        result.signature = InferredSignature.fromDefinition(definition);
        return result;
    }
}

TypedMacroDefinition[string] inferMacroSignatures(Context context)
{
    import std.array;
    import std.algorithm;
    import std.range;

    auto macroDefinitions = parseMacroDefinitions(
        context.translUnit.cursor.children(true),
        context.typeNames());

    auto inferenceContext = new InferenceContext();
    inferenceContext.globalTypes = context.typeNames();
    inferenceContext.queue = DList!TypedMacroDefinition(
        macroDefinitions.map!(TypedMacroDefinition.fromDefinition));
    inferenceContext.definitions = assocArray(
        zip(
            inferenceContext.queue[]
                .map!((TypedMacroDefinition x) => x.definition.spelling),
            inferenceContext.queue[]));

    while (!inferenceContext.queue.empty)
    {
        inferMacroSignature(
            inferenceContext,
            inferenceContext.queue.front);

        inferenceContext.queue.removeFront();
    }

    foreach (definition; inferenceContext.definitions)
        definition.signature.result = inferExpressionType(definition.expr);

    return inferenceContext.definitions;
}
