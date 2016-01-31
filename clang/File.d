/**
 * Copyright: Copyright (c) 2011 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Jan 29, 2012
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module clang.File;

import clang.c.Index;
import clang.Util;

struct File
{
    mixin CX;

    string name()
    {
        return toD(clang_getFileName(cx));
    }

    string toString()
    {
        return name;
    }
}
