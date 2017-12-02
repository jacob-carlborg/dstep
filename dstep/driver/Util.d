/**
 * Copyright: Copyright (c) 2017 Jacob Carlborg. All rights reserved.
 * Authors: Jacob Carlborg
 * Version: Initial created: Nov 30, 2017
 * License: $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0)
 */
module dstep.driver.Util;

string makeDefaultOutputFile(string inputFile, bool useBaseName = true)
{
    import std.path : baseName, setExtension;

    if (useBaseName)
        return setExtension(baseName(inputFile), "d");

    return setExtension(inputFile, "d");
}
