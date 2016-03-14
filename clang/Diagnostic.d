/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Diagnostic;

import std.typecons : RefCounted;

import clang.c.Index;
import clang.Util;

struct Diagnostic
{
    mixin CX;

    string format (uint options = clang_defaultDiagnosticDisplayOptions)
    {
        return toD(clang_formatDiagnostic(cx, options));
    }

    @property CXDiagnosticSeverity severity ()
    {
        return clang_getDiagnosticSeverity(cx);
    }

    @property toString()
    {
        return format;
    }
}

struct DiagnosticSet
{
    private struct Container
    {
        CXDiagnosticSet set;

        ~this()
        {
            if (set != null)
            {
                clang_disposeDiagnosticSet(set);
            }
        }
    }

    private RefCounted!Container container;
    private size_t begin;
    private size_t end;

    private static RefCounted!Container makeContainer(
        CXDiagnosticSet set)
    {
        RefCounted!Container result;
        result.set = set;
        return result;
    }

    private this(
        RefCounted!Container container,
        size_t begin,
        size_t end)
    {
        this.container = container;
        this.begin = begin;
        this.end = end;
    }

    this(CXDiagnosticSet set)
    {
        container = makeContainer(set);
        begin = 0;
        end = clang_getNumDiagnosticsInSet(container.set);
    }

    @property bool empty() const
    {
        return begin >= end;
    }

    @property Diagnostic front()
    {
        return Diagnostic(clang_getDiagnosticInSet(container.set, cast(uint) begin));
    }

    @property Diagnostic back()
    {
        return Diagnostic(clang_getDiagnosticInSet(container.set, cast(uint) (end - 1)));
    }

    @property void popFront()
    {
        ++begin;
    }

    @property void popBack()
    {
        --end;
    }

    @property DiagnosticSet save()
    {
        return this;
    }

    @property size_t length() const
    {
        return end - begin;
    }

    Diagnostic opIndex(size_t index)
    {
        return Diagnostic(clang_getDiagnosticInSet(container.set, cast(uint) (begin + index)));
    }

    DiagnosticSet opSlice(size_t begin, size_t end)
    {
        return DiagnosticSet(container, this.begin + begin, this.begin + end);
    }

    size_t opDollar() const
    {
        return length;
    }
}
