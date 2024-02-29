/**
 * Copyright: Copyright (c) 2024 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 20, 2024
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.core.Core;

import dstep.core.Optional;

T tap(alias operation, T)(T value)
{
    operation(value);
    return value;
}

auto then(alias operation, T)(T value)
{
    return operation(value);
}

T memoize(T)(ref Optional!T cache, lazy T operation) if (!is(T == delegate))
{
    return memoize(cache, &operation);
}

T memoize(T)(ref Optional!T cache, scope T delegate() operation)
{
    return cache.or(operation().tap!((T e) => cache = e));
}

template flatMap(func...)
if (func.length >= 1)
{
    import std.range : isInputRange;
    import std.traits : Unqual;
    import std.algorithm : cache, map, joiner;

    auto flatMap(Range)(Range range)
    if (isInputRange!(Unqual!Range)) => range.map!func.cache.joiner;
}

///
unittest
{
    import std.algorithm : equal;

    [1, 2, 3, 4]
        .flatMap!(e => [e, -e])
        .equal([1, -1, 2, -2, 3, -3, 4, -4]);
}
