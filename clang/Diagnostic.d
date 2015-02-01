/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Oct 6, 2011
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.Diagnostic;

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
}