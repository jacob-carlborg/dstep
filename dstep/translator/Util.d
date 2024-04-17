/**
 * Copyright: Copyright (c) 2024 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Mar 24, 2024
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.translator.Util;

mixin template ToString()
{
    string toString()
    {
        import std.format : format;

        string[] formattedFields;
        formattedFields.reserve(this.tupleof.length);

        foreach (i, field; this.tupleof)
            formattedFields ~= format!"%s: %s"(__traits(identifier, this.tupleof[i]), field);

        return format!"%s(%-(%s, %))"(typeof(this).stringof, formattedFields);
    }
}
