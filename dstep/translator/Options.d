/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: May 21, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

module dstep.translator.Options;

enum Language
{
    c,
    objC
}

struct Options
{
    string outputFile;
    Language language = Language.c;
    bool enableComments = true;
}
