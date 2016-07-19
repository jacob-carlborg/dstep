/**
 * Copyright: Copyright (c) 2016 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.Configuration;

import dstep.translator.Options;

/**
 *  Aggregation of global configuration options affecting the program
 */
struct Configuration
{
    /// array of file names to translate to D
    string[] inputFiles;

    /// expected programming language of input files
    Language language;

    /// array of parameters needed to be forwarded to clang driver
    string[] clangParams;

    /// output file name or folder (in case there are many input files)
    string output;

    /// strip all comments while translating
    bool noComments;
}
