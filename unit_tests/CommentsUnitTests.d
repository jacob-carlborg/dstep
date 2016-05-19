/**
 * Copyright: Copyright (c) 2016 Wojciech Szęszoł. All rights reserved.
 * Authors: Wojciech Szęszoł
 * Version: Initial created: May 21, 2016
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */

import std.stdio;
import Common;
import dstep.translator.Translator;

// Empty file translates to empty file.
unittest
{
    assertTranslates(
q"C
C",
q"D
D", true);
}

// Test disabled comments.
unittest
{
    Options options;
    options.language = Language.c;
    options.enableComments = false;

    assertTranslates(
q"C
    /* Disabled comments. */
C",
q"D
D", options, false);
}

// Test single comment.
unittest
{
    assertTranslates(
q"C
/* Enabled comments. */
C",
q"D
/* Enabled comments. */
D", true);
}

// Test header comment handling.
unittest
{
	assertTranslates(
q"C
/* Header comment. */

/* Comment before variable. */
int variable;
C",
q"D
/* Header comment. */

extern (C):

/* Comment before variable. */
extern __gshared int variable;
D", true);

    assertTranslates(
q"C

/* Header comment. */

/* Comment before variable. */
int variable;
C",
q"D
extern (C):

/* Header comment. */

/* Comment before variable. */
extern __gshared int variable;
D", true);

	assertTranslates(
q"C
/* Header
   comment.
*/

/* Comment before variable. */
int variable;
C",
q"D
/* Header
   comment.
*/

extern (C):

/* Comment before variable. */
extern __gshared int variable;
D", true);

}
