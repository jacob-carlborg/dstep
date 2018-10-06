module tests.support.DStepRunner;

import std.process : execute;
import std.traits : ReturnType;

version (linux)
    version = OptionalGNUStep;

version (Windows)
    version = OptionalGNUStep;

private alias TestRunDStepResult = ReturnType!execute;

auto testRunDStep(
    string[] sourcePaths,
    string[] arguments,
    string[]* outputContents = null,
    string* command = null,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import core.exception : AssertError;

    import std.algorithm : canFind, map;
    import std.file : exists, isFile, readText, rmdirRecurse;
    import std.path : buildPath;
    import std.range : join;
    import std.array : empty;

    import dstep.driver.Util : makeDefaultOutputFile;

    version (OptionalGNUStep)
    {
        if (arguments.canFind("-ObjC") || arguments.canFind("--objective-c"))
        {
            auto extra = findExtraGNUStepPaths(file, line);

            if (extra.empty)
                throw new NoGNUStepException();
            else
                arguments ~= extra;
        }
    }

    foreach (sourcePath; sourcePaths)
        assertFileExists(sourcePath, file, line);

    string outputDir = namedTempDir("dstepUnitTest");
    scope(exit) rmdirRecurse(outputDir);

    string[] outputPaths;

    if (sourcePaths.length == 1)
    {
        outputPaths ~= buildPath(outputDir,
            makeDefaultOutputFile(sourcePaths[0], false));
    }
    else
    {
        foreach (sourcePath; sourcePaths)
            outputPaths ~= buildPath(outputDir,
                makeDefaultOutputFile(sourcePath, false));
    }

    auto localCommand = ["./bin/dstep"] ~ sourcePaths ~ arguments;

    if (outputPaths.length == 1)
        localCommand ~= ["-o", outputPaths[0]];
    else
        localCommand ~= ["-o", outputDir];

    if (command)
        *command = join(localCommand, " ");

    auto result = execute(localCommand);

    if (outputContents)
        outputContents.length = outputPaths.length;

    foreach (i, outputPath; outputPaths)
    {
        if (!exists(outputPath) || !isFile(outputPath))
            throw new NoOutputFile(result, outputPath);

        if (outputContents)
            (*outputContents)[i] = readText(outputPath);
    }

    return result;
}

class NoOutputFile : object.Exception
{
    TestRunDStepResult result;
    string path;

    this (TestRunDStepResult result, string path, string file = __FILE__, size_t line = __LINE__)
    {
        super(path, file, line);
        this.result = result;
        this.path = path;
    }
}

class NoGNUStepException : object.Exception
{
    this (string file = __FILE__, size_t line = __LINE__)
    {
        super("Cannot find GNUStep.", file, line);
    }
}

private:

class NamedTempDirException : object.Exception
{
    import std.format : format;

    immutable string path;

    this (string path, string file = __FILE__, size_t line = __LINE__)
    {
        this.path = path;

        super(
            format("Cannot create temporary directory \"%s\".", path),
            file,
            line
        );
    }
}

void assertFileExists(
    string expected,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import core.exception : AssertError;

    import std.format : format;

    import tests.support.Util : fileExists;

    if (!fileExists(expected))
    {
        auto message = format("File %s doesn't exist.", expected);
        throw new AssertError(message, file, line);
    }
}

version (Posix)
    import core.sys.posix.stdlib : mkdtemp;
else
{
    import core.sys.windows.objbase : CoCreateGuid;
    import core.sys.windows.basetyps : GUID;
}

string namedTempDir(string prefix)
{
    import std.file;
    import std.path;
    import std.format;

    version (Posix)
    {
        static void randstr (char[] slice)
        {
            import std.random;

            foreach (i; 0 .. slice.length)
                slice[i] = uniform!("[]")('A', 'Z');
        }

        string name = format("%sXXXXXXXXXXXXXXXX\0", prefix);
        char[] path = buildPath(tempDir(), name).dup;
        const size_t termAnd6XSize = 7;

        immutable size_t begin = path.length - name.length + prefix.length;

        randstr(path[begin .. $ - termAnd6XSize]);

        char* result = mkdtemp(path.ptr);

        path = path[0..$-1];

        if (result == null)
            throw new NamedTempDirException(path.idup);

        return path.idup;
    }
    else
    {
        static string createGUID()
        {
            static char toHex(uint x)
            {
                if (x < 10)
                    return cast(char) ('0' + x);
                else
                    return cast(char) ('A' + x - 10);
            }

            GUID guid;
            CoCreateGuid(&guid);

            ubyte* data = cast(ubyte*)&guid;
            char[32] result;

            foreach (i; 0 .. 16)
            {
                result[i * 2 + 0] = toHex(data[i] & 0x0fu);
                result[i * 2 + 1] = toHex(data[i] >> 16);
            }

            return result.idup;
        }

        string name = prefix ~ createGUID();
        string path = buildPath(tempDir(), name);

        try
            mkdirRecurse(path);
        catch (FileException)
            throw new NamedTempDirException(path);

        return path;
    }
}

string[] findExtraGNUStepPaths(string file, size_t line)
{
    import std.stdio : stderr;
    import std.format : format;

    auto gnuStepPath = findGNUStepIncludePath();

    if (gnuStepPath == null)
    {
        auto message = "Unable to check the assertion. GNUstep couldn't be found.";
        stderr.writeln(format("Warning@%s(%d): %s", file, line, message));
        return [];
    }

    auto ccIncludePaths = findCcIncludePaths();

    if (ccIncludePaths == null)
    {
        auto message = "Unable to check the assertion. cc include paths couldn't be found.";
        stderr.writeln(format("Warning@%s(%d): %s", file, line, message));
        return [];
    }

    return ccIncludePaths ~ gnuStepPath;
}

string findGNUStepIncludePath()
{
    import std.file : isDir, exists;
    import std.format : format;

    string path = "/usr/include/GNUstep";

    if (exists(path) && isDir(path))
        return format("-I%s", path);
    else
        return null;
}

string[] findCcIncludePaths()
{
    import std.process : executeShell;
    auto result = executeShell("cc -E -v - < /dev/null");

    if (result.status == 0)
        return extractIncludePaths(result.output);
    else
        return null;
}

string[] extractIncludePaths(string output)
{
    import std.algorithm.searching;
    import std.algorithm.iteration;
    import std.array : array;
    import std.string;

    string start = "#include <...> search starts here:";
    string stop = "End of search list.";

    auto paths = output.findSplitAfter(start)[1]
        .findSplitBefore(stop)[0].strip();
    auto args = map!(a => format("-I%s", a.strip()))(paths.splitLines());
    return paths.empty ? null : args.array;
}
