/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Dec 17, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

// Fix 102: Regression: usage of typedefs within structs.
unittest
{
    assertTranslates(q"C
typedef struct _ProtobufCMethodDescriptor ProtobufCMethodDescriptor;

struct _ProtobufCMethodDescriptor
{
    const char *name;
    const ProtobufCMethodDescriptor *input;
    const ProtobufCMethodDescriptor *output;
};
C",
q"D
extern (C):

alias ProtobufCMethodDescriptor = _ProtobufCMethodDescriptor;

struct _ProtobufCMethodDescriptor
{
    const(char)* name;
    const(ProtobufCMethodDescriptor)* input;
    const(ProtobufCMethodDescriptor)* output;
}
D");

}
