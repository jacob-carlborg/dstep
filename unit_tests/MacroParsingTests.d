/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 03, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
import std.stdio;
import Common;
import Assert;

import clang.c.Index;
import clang.Type;

import dstep.translator.Context;
import dstep.translator.MacroDefinition;
import dstep.translator.MacroDefinitionParser;

alias parse = parseMacroDefinition;

Type parseTypeName(string source)
{
    Cursor[string] table;
    auto tokens = tokenize(source);
    return dstep.translator.MacroDefinitionParser.parseTypeName(tokens, table);
}



unittest
{
    auto x = parse("");
    assert(x is null);

    auto y = parse("#define FOO");
    assert(y !is null);
    assert(y.spelling == "FOO");
    assert(y.constant == true);

    auto z = parse("#define FOO()");
    assert(z !is null);
    assert(z.spelling == "FOO");
    assert(z.constant == false);
    assert(z.params == []);

    auto w = parse("#define FOO(a, b)");
    assert(w !is null);
    assert(w.spelling == "FOO");
    assert(w.constant == false);
    assert(w.params.length == 2);
    assert(w.params[0] == "a");
    assert(w.params[1] == "b");

    auto a = parse("#define FOO 1");
    assert(a !is null);
    assert(typeid(a.expr) == typeid(Literal));
    assert((cast(Literal) a.expr).spelling == "1");

    auto b = parse("#define FOO(p) #p");
    assert(b !is null);
    assert(typeid(b.expr) == typeid(StringifyExpr));
    assert((cast(StringifyExpr) b.expr).spelling == "p");

    auto c = parse(`#define STRINGIZE(major, minor) #major"."#minor`);
    assert(c !is null);
    assert(c.expr !is null);
    assert(cast(StringConcat) c.expr !is null);
    auto cSubstrings = (cast(StringConcat) c.expr).substrings;
    assert(cSubstrings.length == 3);
    assert(cast(StringifyExpr) cSubstrings[0] !is null);
    assert(cast(StringLiteral) cSubstrings[1] !is null);
    assert(cast(StringifyExpr) cSubstrings[2] !is null);
    assert((cast(StringifyExpr) cSubstrings[0]).spelling == "major");
    assert((cast(StringLiteral) cSubstrings[1]).spelling == `"."`);
    assert((cast(StringifyExpr) cSubstrings[2]).spelling == "minor");

    auto d = parse(`#define VERSION ENCODE(MAJOR, MINOR)`);
    assert(d !is null && d.expr !is null && cast(CallExpr) d.expr !is null);
    auto dCallExpr = cast(CallExpr) d.expr;
    assert(dCallExpr.args.length == 2);
    assert((cast(Identifier) dCallExpr.args[0]) !is null);
    assert((cast(Identifier) dCallExpr.args[0]).spelling == "MAJOR");
    assert((cast(Identifier) dCallExpr.args[1]) !is null);
    assert((cast(Identifier) dCallExpr.args[1]).spelling == "MINOR");

    auto e = parse(`#define VERSION ENCODE(MAJOR, MINOR)(PATCH)`);
    assert(d !is null && d.expr !is null && cast(CallExpr) d.expr !is null);
}

// Test collection of type names.
unittest
{
    assertCollectsTypeNames(["foo"], "typedef int foo;");
    assertCollectsTypeNames(["struct foo"], "struct foo { };");
}

// Parse basic types.
unittest
{
    alias localAssert = assertParsedTypeHasKind;

    localAssert("void", CXTypeKind.void_);

    localAssert("float", CXTypeKind.float_);
    localAssert("double", CXTypeKind.double_);
    localAssert("long double", CXTypeKind.longDouble);
    localAssert("bool", CXTypeKind.bool_);
    localAssert("_Bool", CXTypeKind.bool_);

    localAssert("char", CXTypeKind.charS);
    localAssert("signed char", CXTypeKind.sChar);
    localAssert("unsigned char", CXTypeKind.uChar);

    localAssert("short", CXTypeKind.short_);
    localAssert("short int", CXTypeKind.short_);
    localAssert("signed short", CXTypeKind.short_);
    localAssert("signed short int", CXTypeKind.short_);
    localAssert("unsigned short", CXTypeKind.uShort);
    localAssert("unsigned short int", CXTypeKind.uShort);
    localAssert("short unsigned int", CXTypeKind.uShort);
    localAssert("short int unsigned", CXTypeKind.uShort);

    localAssert("int", CXTypeKind.int_);
    localAssert("signed", CXTypeKind.int_);
    localAssert("signed int", CXTypeKind.int_);
    localAssert("unsigned", CXTypeKind.uInt);
    localAssert("unsigned int", CXTypeKind.uInt);

    localAssert("long", CXTypeKind.long_);
    localAssert("long int", CXTypeKind.long_);
    localAssert("signed long", CXTypeKind.long_);
    localAssert("signed long int", CXTypeKind.long_);
    localAssert("unsigned long", CXTypeKind.uLong);
    localAssert("unsigned long int", CXTypeKind.uLong);
    localAssert("long unsigned int", CXTypeKind.uLong);
    localAssert("int unsigned long", CXTypeKind.uLong);

    localAssert("long long", CXTypeKind.longLong);
    localAssert("long long int", CXTypeKind.longLong);
    localAssert("signed long long", CXTypeKind.longLong);
    localAssert("signed long long int", CXTypeKind.longLong);
    localAssert("unsigned long long", CXTypeKind.uLongLong);
    localAssert("unsigned long long int", CXTypeKind.uLongLong);
    localAssert("long unsigned int long", CXTypeKind.uLongLong);
    localAssert("int long unsigned long", CXTypeKind.uLongLong);
}

// Do not parse invalid types.
unittest
{
    alias localAssert = assertTypeIsntParsed;

    localAssert("char char");
    localAssert("char int");
    localAssert("void void");
    localAssert("void int");
    localAssert("unsigned void");
    localAssert("signed unsigned");
    localAssert("signed unsigned int");
    localAssert("float int");
    localAssert("unsinged float");
    localAssert("double float");
    localAssert("float double");
    localAssert("unsinged double");
    localAssert("double double");
}

// Parse pointers in combination with consts.
unittest
{
    Type t0 = parseTypeName("int");

    assert(!t0.isConst);
    assert(t0.kind == CXTypeKind.int_);


    Type t1 = parseTypeName("const int");

    assert(t1.isConst);
    assert(t1.kind == CXTypeKind.int_);


    Type t2 = parseTypeName("const int*");

    assert(t2.isPointer);
    assert(!t2.isConst);
    assert(t2.pointee.kind == CXTypeKind.int_);
    assert(t2.pointee.isConst);


    Type t3 = parseTypeName("const int**");

    assert(t3.isPointer);
    assert(!t3.isConst);
    assert(t3.pointee.isPointer);
    assert(!t3.pointee.isConst);
    assert(t3.pointee.pointee.kind == CXTypeKind.int_);
    assert(t3.pointee.pointee.isConst);


    Type t4 = parseTypeName("const int***");

    assert(t4.isPointer);
    assert(t4.pointee.isPointer);
    assert(t4.pointee.pointee.isPointer);
    assert(t4.pointee.pointee.pointee.kind == CXTypeKind.int_);


    Type t5 = parseTypeName("int***");

    assert(t5.isPointer);
    assert(t5.pointee.isPointer);
    assert(t5.pointee.pointee.isPointer);
    assert(t5.pointee.pointee.pointee.kind == CXTypeKind.int_);


    Type t6 = parseTypeName("int *const *const *const");

    assert(t6.isPointer);
    assert(t6.isConst);
    assert(t6.pointee.isPointer);
    assert(t6.pointee.isConst);
    assert(t6.pointee.pointee.isPointer);
    assert(t6.pointee.pointee.isConst);
    assert(t6.pointee.pointee.pointee.kind == CXTypeKind.int_);
    assert(!t6.pointee.pointee.pointee.isConst);


    Type t7 = parseTypeName("int const * *const *const");

    assert(t7.isPointer);
    assert(t7.isConst);
    assert(t7.pointee.isPointer);
    assert(t7.pointee.isConst);
    assert(t7.pointee.pointee.isPointer);
    assert(!t7.pointee.pointee.isConst);
    assert(t7.pointee.pointee.pointee.kind == CXTypeKind.int_);
    assert(t7.pointee.pointee.pointee.isConst);


    Type t8 = parseTypeName("int * * *const");

    assert(t8.isPointer);
    assert(t8.isConst);
    assert(t8.pointee.isPointer);
    assert(!t8.pointee.isConst);
    assert(t8.pointee.pointee.isPointer);
    assert(!t8.pointee.pointee.isConst);
    assert(t8.pointee.pointee.pointee.kind == CXTypeKind.int_);
    assert(!t8.pointee.pointee.pointee.isConst);


    Type t9 = parseTypeName("int * *const *");

    assert(t9.isPointer);
    assert(!t9.isConst);
    assert(t9.pointee.isPointer);
    assert(t9.pointee.isConst);
    assert(t9.pointee.pointee.isPointer);
    assert(!t9.pointee.pointee.isConst);
    assert(t9.pointee.pointee.pointee.kind == CXTypeKind.int_);
    assert(!t9.pointee.pointee.pointee.isConst);
}
