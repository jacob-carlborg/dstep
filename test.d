module test;

import std.process;
import std.stdio;
import std.file;
import std.path;
import std.algorithm;
import std.string;
import std.traits : ReturnType;

void main ()
{
    TestRunner().run();
}

private:

/**
 * The available test groups.
 *
 * The tests will be run in the order specified here.
 */
enum TestGroup
{
    unit = "unit",
    library = "library",
    functional = "functional"
}

struct TestRunner
{
    void run ()
    {
        import std.traits : EnumMembers;

        foreach (test ; EnumMembers!TestGroup)
            runTest!(test);

        stdout.flush();
    }

    /**
     * Run a single group of tests, i.e. functional, library or unit test.
     *
     * Params:
     *  testGroup = the test group to run
     *
     * Returns: the exist code of the test run
     */
    void runTest (TestGroup testGroup)()
    {
        import std.string : capitalize;

        enum beforeFunction = "before" ~ testGroup.capitalize;

        static if (is(typeof(mixin(beforeFunction))))
            mixin(beforeFunction ~ "();");

        writef("Running %s tests ", testGroup);
        stdout.flush();
        const command = dubShellCommand("--config=test-" ~ testGroup);
        executeCommand(command);
    }

    void beforeFunctional() @safe
    {
        if (dstepBuilt)
            return;

        writeln("Building DStep");
        const command = dubShellCommand("build", "--build=debug");
        executeCommand(command);
    }
}

@safe:

bool dstepBuilt()
{
    import std.file : exists;

    version (Windows)
        enum dstepPath = "bin/dstep.exe";
    else version (Posix)
        enum dstepPath = "bin/dstep";

    return exists(dstepPath);
}

void executeCommand(const string[] args ...)
{
    import std.process : spawnProcess, wait;
    import std.array : join;

    if (spawnProcess(args).wait() != 0)
        throw new Exception("Failed to execute command: " ~ args.join(' '));
}

string[] dubShellCommand(string[] subCommands ...)
{
    return ["dub", "--verror"] ~ subCommands ~ dubArch;
}

string defaultArchitecture()
{
    version (X86_64)
        return "x86_64";
    else
    {
        version (DigitalMars)
            return "x86_mscoff";
        else
            return "x86";
    }
}

string dubArch()
{
    version (Windows)
    {
        import std.process : environment;
        import std.string : split;

        const architecture = environment
            .get("DUB_ARCH", defaultArchitecture)
            .split(" ")[$ - 1];

        return "--arch=" ~ architecture;

    }
    else
        return "";
}
