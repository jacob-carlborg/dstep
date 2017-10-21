/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: Aug 03, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import Common;

// Fix 10: Embedded struct not generated.
unittest
{
    assertTranslates(q"C
struct info {
  long remote_ip;
  int remote_port;
  int is_ssl;
  void *user_data;

  struct mg_header {
    const char *name;
    const char *value;
  } headers[64];
};
C",
q"D
import core.stdc.config;

extern (C):

struct info
{
    c_long remote_ip;
    int remote_port;
    int is_ssl;
    void* user_data;

    struct mg_header
    {
        const(char)* name;
        const(char)* value;
    }

    mg_header[64] headers;
}
D");

}
