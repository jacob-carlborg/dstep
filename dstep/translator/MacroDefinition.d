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
import clang.Util;
import clang.SourceLocation;
import clang.SourceRange;
import clang.Token;
import clang.Type;

import dstep.translator.Context;
import dstep.translator.MacroDefinitionParser;
import dstep.translator.Output;
import dstep.translator.Type;

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

    CallExpr expr = cast(CallExpr) definition.expr;
    Set!string imports;

    if (expr !is null)
    {
        Identifier ident = cast(Identifier) expr.expr;

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

class FunctDirective
{
    string spelling;
    string[] paramNames;
    ExprType returnType;
    ExprType[string] paramTypes;
    Expression expression;

    override string toString()
    {
        import std.format : format;

        return format(
            "FunctDirective(spelling = %s, paramNames = %s, " ~
            "returnType = %s, paramTypes = %s, expression = %s)",
            spelling,
            paramNames,
            returnType,
            paramTypes,
            expression);
    }
}

bool translateFunctDirectiveAlias(
    Output output,
    Context context,
    FunctDirective function_)
{
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : map;

    Set!string imports;
    Set!string params;

    CallExpr expression = cast(CallExpr) function_.expression;

    if (expression !is null)
    {
        Identifier identifier = cast(Identifier) expression.expr;

        if (identifier.spelling == "assert")
        {
            // aliasing `assert` from C "assert.h" is commong enough to warrant
            // a special case to use function instead of an alias
            output.singleLine("void %s(T...)(T args)", function_.spelling);
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

        if (identifier !is null &&
            equal(function_.paramNames, expression.args.map!(
                a => a.translate(context, params, imports))))
        {
            version (D1)
                enum fmt = "alias %2$s %1$s;";
            else
                enum fmt = "alias %1$s = %2$s;";

            output.singleLine(fmt, function_.spelling, identifier.spelling);
            return true;
        }
    }

    return false;
}

void translateFunctDirective(
    Output output,
    Context context,
    FunctDirective function_)
{
    import std.format : format;
    import std.array : join;

    Set!string params;
    string typeStrings = "";
    string paramStrings = "";

    if (function_.paramNames.length != 0)
    {
        auto typeList = translateDirectiveTypeList(
            function_.paramNames,
            function_.paramTypes);

        if (typeList != "")
            typeStrings = format("(%s)", typeList);

        paramStrings = translateDirectiveParamList(
            function_.paramNames,
            function_.paramTypes);

        foreach (param; function_.paramTypes.byKey)
            params.add(param);
    }

    Set!string imports;

    auto expression = function_.expression.debraced;
    auto translated = expression.translate(context, params, imports);

    output.subscopeStrong(
        "%s%s %s%s(%s)",
        "extern (D) ",
        function_.returnType.asReturnType(),
        function_.spelling,
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

FunctDirective translateFunctDirective(
    Context context,
    MacroDefinition definition)
{
    auto function_ = new FunctDirective();
    function_.spelling = definition.spelling;
    function_.paramNames = definition.params;
    function_.returnType = definition.expr.guessExprType();

    foreach (param; definition.params)
        function_.paramTypes[param] = ExprType(ExprType.kind.unspecified);

    definition.expr.guessParamTypes(
        context,
        function_.paramTypes,
        function_.returnType);

    function_.expression = definition.expr;

    return function_;
}

FunctDirective translateFunctDirective(
    Context context,
    Cursor cursor)
{
    assert(cursor.kind == CXCursorKind.macroDefinition);

    auto tokens = cursor.tokens;
    auto definition = parsePartialMacroDefinition(tokens, context.typeNames);

    if (definition !is null && definition.expr !is null && !definition.constant)
        return translateFunctDirective(context, definition);
    else
        return null;
}

void translateMacroDefinition(Output output, Context context, Cursor cursor)
{
    assert(cursor.kind == CXCursorKind.macroDefinition);

    auto tokens = cursor.tokens;
    auto definition = parsePartialMacroDefinition(tokens, context.typeNames);

    if (definition !is null && definition.expr !is null)
    {
        if (definition.constant)
            translateConstDirective(output, context, definition);
        else
        {
            FunctDirective directive = translateFunctDirective(
                context,
                definition);

            if (!translateFunctDirectiveAlias(output, context, directive))
            {
                translateFunctDirective(output, context, directive);
            }
        }
    }
}
