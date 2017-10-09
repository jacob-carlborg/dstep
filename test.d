module test;

import std.process;
import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.string;
import std.exception;

int main ()
{
    return TestRunner().run;
}

struct TestRunner
{
    private string wd;

    int run ()
    {
        int result = 0;
        activate();

        auto output = execute(["./bin/dstep", "--clang-version"]);

        writeln("Testing with ", strip(output.output));
        result += unitTest();
        result += libraryTest();
        stdout.flush();

        return result;
    }

    string workingDirectory ()
    {
        if (wd.length)
            return wd;

        return wd = getcwd();
    }

    string clangBasePath ()
    {
        return buildNormalizedPath(workingDirectory, "clangs");
    }

    void activate ()
    {
        version (Windows)
        {
            auto src = buildNormalizedPath(workingDirectory, clang.versionedLibclang);
            auto dest = buildNormalizedPath(workingDirectory, clang.libclang);

            if (exists(dest))
                remove(dest);

            copy(src, dest);

            auto staticSrc = buildNormalizedPath(workingDirectory, clang.staticVersionedLibclang);
            auto staticDest = buildNormalizedPath(workingDirectory, clang.staticLibclang);

            if (exists(staticDest))
                remove(staticDest);

            copy(staticSrc, staticDest);
        }
        else
            execute(["./configure", "--llvm-path", "clangs/clang/lib"]);

        build();
        writeln(" [DONE]");
    }

    int unitTest ()
    {
        writeln("Running unit tests ");

        auto result = executeShell(dubShellCommand("test"));

        if (result.status != 0)
            writeln(result.output);

        return result.status;
    }

    /**
       Test that dstep can be used as a library by compiling a dependent
       dub package
     */
    int libraryTest ()
    {
        const string[string] env;
        const config = Config.none;
        const maxOutput = size_t.max;
        const workDir = "tests/functional/test_package";
        const result = executeShell(dubShellCommand("build"),
                                    env,
                                    config,
                                    maxOutput,
                                    workDir);
        if (result.status != 0)
            writeln(result.output);

        return result.status;
    }

    void build ()
    {
        try
        {
            auto result = executeShell(dubShellCommand("build"));

            if (result.status != 0)
            {
                writeln(result.output);
                throw new Exception("Failed to build DStep");
            }
        }
        catch(ProcessException)
        {
            throw new ProcessException("Failed to execute dub");
        }
    }
}


private string dubShellCommand(string subCommand) @safe pure nothrow
{
    return "dub " ~ subCommand ~ dubArch;
}

private string dubArch() @safe pure nothrow
{
    version (Windows)
    {
        version (X86_64)
            return " --arch=x86_64";
        else
            return " --arch=x86_mscoff";
    }
    else
    {
        return "";
    }
}
