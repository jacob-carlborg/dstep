/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 03, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import std.stdio;
import Common;
import dstep.translator.MacroDefinition;

alias parse = parseMacroDefinition;

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
    assert((cast (Literal) a.expr).spelling == "1");

    auto b = parse("#define FOO(p) #p");
    assert(b !is null);
    assert(typeid(b.expr) == typeid(StringifyExpr));
    assert((cast (StringifyExpr) b.expr).spelling == "p");

    auto c = parse(`#define STRINGIZE(major, minor) #major"."#minor`);
    assert(c !is null);
    assert(c.expr !is null);
    assert(cast (StringConcat) c.expr !is null);
    auto cSubstrings = (cast (StringConcat) c.expr).substrings;
    assert(cSubstrings.length == 3);
    assert(cast (StringifyExpr) cSubstrings[0] !is null);
    assert(cast (StringLiteral) cSubstrings[1] !is null);
    assert(cast (StringifyExpr) cSubstrings[2] !is null);
    assert((cast (StringifyExpr) cSubstrings[0]).spelling == "major");
    assert((cast (StringLiteral) cSubstrings[1]).spelling == `"."`);
    assert((cast (StringifyExpr) cSubstrings[2]).spelling == "minor");

    auto d = parse(`#define VERSION ENCODE(MAJOR, MINOR)`);
    assert(d !is null && d.expr !is null && cast (CallExpr) d.expr !is null);
    auto dCallExpr = cast (CallExpr) d.expr;
    assert(dCallExpr.args.length == 2);
    assert((cast (Identifier) dCallExpr.args[0]) !is null);
    assert((cast (Identifier) dCallExpr.args[0]).spelling == "MAJOR");
    assert((cast (Identifier) dCallExpr.args[1]) !is null);
    assert((cast (Identifier) dCallExpr.args[1]).spelling == "MINOR");

    auto e = parse(`#define VERSION ENCODE(MAJOR, MINOR)(PATCH)`);
    assert(d !is null && d.expr !is null && cast (CallExpr) d.expr !is null);
}



