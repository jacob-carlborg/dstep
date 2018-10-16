import std.stdio;
import std.process : spawnProcess, Config, wait;

@safe:

void main()
{
    executeCommand(dubShellCommand());
}

string[] dubShellCommand() pure nothrow
{
    return ["dub", "run", "--verror"] ~ dubArch;
}

void executeCommand(const string[] args ...)
{
    import std.process : spawnProcess, wait;
    import std.array : join;

    immutable string[string] env;
    immutable config = Config.none;
    immutable workDir = "tests/functional/test_package";


    if (spawnProcess(args, env, config, workDir).wait() != 0)
        throw new Exception("Failed to execute command: " ~ args.join(' '));
}

string dubArch() pure nothrow
{
    version (Win64)
        return "--arch=x86_64";

    else version (Win32)
    {
        version (DigitalMars)
            return "--arch=x86_mscoff";
        else
            return "--arch=x86";
    }

    else
        return "";
}
