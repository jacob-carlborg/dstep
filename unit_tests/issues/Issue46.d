/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jun 27, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

import dstep.translator.Options;

// Fix 46: Generating code that will not compile.
unittest
{
    Options options;
    options.reduceAliases = true;

    assertTranslates(
q"C

typedef unsigned char __u8;
typedef unsigned int __u32;
typedef __signed__ long __s64;
typedef unsigned long __u64;

struct stats_t {
    __u8 scale;
    union {
        __u64 uvalue;
        __s64 svalue;
    };
} __attribute__ ((packed));


#define MAX_STATS   4

struct fe_stats_t {
    __u8 len;
    struct stats_t stat[MAX_STATS];
} __attribute__ ((packed));

struct property_t {
    __u32 cmd;
    __u32 reserved[3];
    union {
        __u32 data;
        struct fe_stats_t st;
        struct {
            __u8 data[32];
            __u32 len;
            __u32 reserved1[3];
            void *reserved2;
        } buffer;
    } u;
    int result;
} __attribute__ ((packed));
C",
q"D
extern (C):

struct stats_t
{
    align (1):

    ubyte scale;

    union
    {
        ulong uvalue;
        long svalue;
    }
}

enum MAX_STATS = 4;

struct fe_stats_t
{
    align (1):

    ubyte len;
    stats_t[MAX_STATS] stat;
}

struct property_t
{
    align (1):

    uint cmd;
    uint[3] reserved;

    union _Anonymous_0
    {
        uint data;
        fe_stats_t st;

        struct _Anonymous_1
        {
            ubyte[32] data;
            uint len;
            uint[3] reserved1;
            void* reserved2;
        }

        _Anonymous_1 buffer;
    }

    _Anonymous_0 u;
    int result;
}
D", options);

}
