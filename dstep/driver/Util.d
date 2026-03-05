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

string findBasePath(string[] paths)
{
    import std.algorithm.iteration : filter, map, reduce;
    import std.algorithm.searching : commonPrefix;
    import std.array : array;
    import std.path : isAbsolute, dirName, pathSplitter, buildPath;

    auto absolutePaths = paths.filter!isAbsolute.array;
    if (absolutePaths.length == 0)
        return ".";

    version (Windows)
    {
        import std.string : replace;
        absolutePaths = absolutePaths.map!(p => p.replace("/", "\\")).array;
    }

    if (absolutePaths.length == 1)
        return dirName(absolutePaths[0]);

    auto parts = absolutePaths
        .map!(p => pathSplitter(dirName(p)).array)
        .array;

    version (Windows)
    {
        import std.uni : icmp;
        auto common = parts.reduce!((a, b) => commonPrefix!((x, y) => icmp(x, y) == 0)(a, b).array);
    }
    else
    {
        auto common = parts.reduce!((a, b) => commonPrefix(a, b).array);
    }

    if (common.length == 0)
        return ".";

    return buildPath(common);
}

unittest
{
    assert(findBasePath([]) == ".");
    assert(findBasePath(["foo/bar.h", "a/b.h", "c.h"]) == ".");
}

version (Posix)
{
    unittest
    {
        assert(findBasePath(["/usr/include/stdio.h"]) == "/usr/include");
        assert(findBasePath(["foo.h", "/usr/include/sys/stat.h"]) == "/usr/include/sys");
        assert(findBasePath(["/usr/include/stdio.h", "/usr/include/sys/stat.h", "/usr/lib/foo.h"]) == "/usr");
        assert(findBasePath(["/usr/include/stdio.h", "/usr/include/string.h", "/usr/include/stdlib.h"]) == "/usr/include");
        assert(findBasePath(["usr.h", "/usr/include/stdio.h", "/usr/include/sys/stat.h", "/usr/include/string.h", "include.h"]) == "/usr/include");
        assert(findBasePath(["/usr/include/stdio.h", "/usr/Include/stdio.h", "/usR/include/stdio.h"]) == "/");
    }
}

version (Windows)
{
    unittest
    {
        assert(findBasePath(["/usr/include/stdio.h"]) == ".");
        assert(findBasePath(["foo.h", "/usr/include/sys/stat.h"]) == ".");
        assert(findBasePath(["/usr/include/stdio.h", "/usr/include/sys/stat.h", "/usr/lib/foo.h"]) == ".");
        assert(findBasePath(["/usr/include/stdio.h", "/usr/include/string.h", "/usr/include/stdlib.h"]) == ".");
        assert(findBasePath(["usr.h", "/usr/include/stdio.h", "/usr/include/sys/stat.h", "/usr/include/string.h", "include.h"]) == ".");
        assert(findBasePath(["/usr/include/stdio.h", "/usr/Include/stdio.h", "/usR/include/stdio.h"]) == ".");

        assert(findBasePath(["C:/usr/include/stdio.h"]) == "C:\\usr\\include");
        assert(findBasePath(["foo.h", "C:/usr/include/sys/stat.h"]) == "C:\\usr\\include\\sys");
        assert(findBasePath(["C:/usr/include/stdio.h", "C:/usr/include/sys/stat.h", "C:/usr/lib/foo.h"]) == "C:\\usr");
        assert(findBasePath(["C:/usr/include/stdio.h", "C:/usr/include/string.h", "C:/usr/include/stdlib.h"]) == "C:\\usr\\include");
        assert(findBasePath(["usr.h", "D:/usr/include/stdio.h", "D:/usr/include/sys/stat.h", "D:/usr/include/string.h", "include.h"]) == "D:\\usr\\include");
        assert(findBasePath(["E:/usr/include/stdio.h", "E:/usr/Include/stdio.h", "E:/usR/include/stdio.h"]) == "E:\\usr\\include");

        assert(findBasePath(["D:\\test.h"]) == "D:\\");
        assert(findBasePath(["D:\\a\\b.h", "D:\\a\\c.h"]) == "D:\\a");
        assert(findBasePath(["D:\\a\\b.h", "E:\\b.h"]) == ".");
        assert(findBasePath(["D:\\B\\a.h", "D:\\b\\c\\D.h", "D:\\B\\c.h"]) == "D:\\B");
        assert(findBasePath(["D:/a\\b/d.h", "D:\\a/B\\c.h"]) == "D:\\a\\b");
        assert(findBasePath(["C:\\a.h", "D:\\b.h"]) == ".");
    }
}
