/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Jan 26, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;
import dstep.translator.Options;

// Fix 116: struct member expansion
unittest
{
    assertTranslates(q"C

// FILE object wrapper for vfs access
typedef struct {
    struct DB_vfs_s *vfs;
} DB_FILE;

typedef int DB_playItem_t;

typedef struct DB_plugin_action_s {
    const char *title;
    const char *name;
    unsigned flags;
    // only use it if the code must be compatible with API 1.4
    // otherwise switch to callback2
} DB_plugin_action_t;

// vfs plugin
// provides means for reading, seeking, etc
// api is based on stdio
typedef struct DB_vfs_s {
    // capabilities
    const char **(*get_schemes) (void);

    int (*is_streaming) (void); // return 1 if the plugin streaming data

    // this allows interruption of hanging network streams
    void (*abort) (DB_FILE *stream);

    // should return mime-type of a stream, if known; can be NULL
    const char * (*get_content_type) (DB_FILE *stream);

    // associates stream with a track, to allow dynamic metadata updating, like
    // in icy protocol
    void (*set_track) (DB_FILE *f, DB_playItem_t *it);
} DB_vfs_t;
C",
q"D
extern (C):

// FILE object wrapper for vfs access
struct DB_FILE
{
    DB_vfs_s* vfs;
}

alias DB_playItem_t = int;

struct DB_plugin_action_s
{
    const(char)* title;
    const(char)* name;
    uint flags;
    // only use it if the code must be compatible with API 1.4
    // otherwise switch to callback2
}

alias DB_plugin_action_t = DB_plugin_action_s;

// vfs plugin
// provides means for reading, seeking, etc
// api is based on stdio
struct DB_vfs_s
{
    // capabilities
    const(char*)* function () get_schemes;

    int function () is_streaming; // return 1 if the plugin streaming data

    // this allows interruption of hanging network streams
    void function (DB_FILE* stream) abort;

    // should return mime-type of a stream, if known; can be NULL
    const(char)* function (DB_FILE* stream) get_content_type;

    // associates stream with a track, to allow dynamic metadata updating, like
    // in icy protocol
    void function (DB_FILE* f, DB_playItem_t* it) set_track;
}

alias DB_vfs_t = DB_vfs_s;
D");

}
