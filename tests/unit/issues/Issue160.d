/**
 * Copyright: Copyright (c) 2017 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: August 26, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

// Fix 160: Translating typedef of function pointer doesn't take line length
// into consideration
unittest
{
    assertTranslates(q"C
typedef struct { } CXFile;
typedef struct { } CXSourceLocation;
typedef struct { } CXClientData;

typedef void (*CXInclusionVisitor)(CXFile included_file,
                                   CXSourceLocation* inclusion_stack,
                                   unsigned include_len,
                                   CXClientData client_data);
C",
q"D
extern (C):

struct CXFile
{
}

struct CXSourceLocation
{
}

struct CXClientData
{
}

alias CXInclusionVisitor = void function (
    CXFile included_file,
    CXSourceLocation* inclusion_stack,
    uint include_len,
    CXClientData client_data);
D");

}
