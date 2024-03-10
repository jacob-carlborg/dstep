/**
 * Copyright: Copyright (c) 2024 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 12, 2024
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.ApiNotes;

import std.algorithm;
import std.exception;
import std.format;
import std.range;
import std.regex;
import std.traits;

import dyaml;

import dstep.core.Core;
import dstep.core.Optional;

struct ApiNotes
{
    Function[] functions;

    this(RawFunction[] functions)
    {
        this.functions = functions.map!(Function.parse).array;
    }

    this(const Node node, string tag)
    {
        this(
            node["Functions"]
            .sequence
            .map!(e => e.as!RawFunction)
            .array
        );
    }

    static ApiNotes parse(string data)
    {
        if (data.length == 0)
            return ApiNotes();

        return Loader.fromString(data).load.as!ApiNotes;
    }

    Optional!Function lookupFunction(const string name) =>
        functions
            .find!(f => f.name == name)
            .takeOne
            .map!some
            .or(none!Function);

    bool contextExists(const string context) =>
        !functions
            .find!(f => f.context.or("") == context)
            .empty;
}

struct Function
{
    string name;
    Optional!string context;
    string baseName;
    string[] arguments;

    static Function parse(RawFunction rawFunction)
    {
        return Parser(rawFunction).parse();
    }

    mixin ToString;

    bool isConstructor() => isStaticMethod && (baseName == "init" || baseName == "this");
    bool isStaticMethod() => context.isPresent && !isInstanceMethod;
    bool isMethod() => isStaticMethod || isInstanceMethod;

    bool isInstanceMethod() =>
        context.isPresent &&
        arguments.length > 0 &&
        (
            arguments[0] == "this" ||
            arguments[0] == "self"
        );

private:

    static struct Parser
    {
        private RawFunction rawFunction;

        private Optional!string _name;
        private Optional!(Optional!string) _context;
        private Optional!string _baseName;
        private Optional!(string[]) _arguments;
        private Optional!(string[]) _nameComponents;
        private Optional!(string[]) _components;

        this(RawFunction rawFunction)
        {
            this.rawFunction = rawFunction;
        }

        Function parse()
        {
            return Function(
                name: name,
                context: context,
                baseName: baseName,
                arguments: arguments
            );
        }

    private:

        string name() => memoize(_name, rawFunction.name.tap!enforceValidIdentifier);

        Optional!string context() => memoize(_context,
            nameComponents
                .then!(c => c.length == 1 ? none!string : some(c[0]))
                .tap!(c => c.each!enforceValidIdentifier)
        );

        string baseName() => memoize(_baseName,
            nameComponents
                .tap!(c => enforce(c.length >= 1))
                .then!(c => c.length == 1 ? c[0] : c[1])
                .tap!(name => enforceValidIdentifier(name))
        );

        string[] arguments() => memoize(_arguments,
            components.length == 1 ? [] : components[1].split(":").rejectEmpty.array
        );

        string[] nameComponents() => memoize(_nameComponents, components[0].split("."));

        string[] components() => memoize(_components,
            rawFunction
                .dName
                .splitter(regex(r"[\(\)]"))
                .array
                .tap!(c => enforceValidSignature(c.length == 1 || c.length == 3, rawFunction.dName))
                .then!(c => c.rejectEmpty.array)
        );
    }
}

struct RawFunction
{
    string name;
    string dName;

@safe:

    this(string name, string dName)
    {
        this.name = name;
        this.dName = dName;
    }

    this(const Node node, string tag)
    {
        auto name = node["Name"].as!string;
        string dName;

        foreach (key; ["dName", "DName", "SwiftName"])
        {
            if (node.containsKey(key))
            {
                dName = node[key].as!string;
                break;
            }
        }

        this(name, dName);
    }

    mixin ToString;
}

class InvalidIdentifierException : Exception
{
    immutable string identifier;

    this(string identifier, string file = __FILE__, size_t line = __LINE__)
    {
        this.identifier = identifier;
        super("Invalid identifier: " ~ identifier, file, line);
    }
}

class InvalidSignatureException : Exception
{
    immutable string signature;

    this(string signature, string file = __FILE__, size_t line = __LINE__)
    {
        this.signature = signature;
        super("Invalid signature: " ~ signature, file, line);
    }
}

private:

alias enforceValidSignature = enforce!InvalidSignatureException;

void enforceValidIdentifier(string identifier)
{
    enforce!InvalidIdentifierException(identifier.isValidIdentifier, identifier);
}

bool isValidIdentifier(string identifier) =>
    !!identifier.matchFirst(regex(r"^[A-Za-z_]\w*"));

alias rejectEmpty = filter!(e => !e.empty);

mixin template ToString()
{
    string toString()
    {
        string[] formattedFields;
        formattedFields.reserve(this.tupleof.length);

        foreach (i, field; this.tupleof)
            formattedFields ~= format!"%s: %s"(__traits(identifier, this.tupleof[i]), field);

        return format!"%s(%-(%s, %))"(typeof(this).stringof, formattedFields);
    }
}
