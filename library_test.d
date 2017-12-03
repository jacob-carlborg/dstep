import std.stdio;
import std.process : executeShell, Config;

@safe:

int main()
{
    writeln("Running library tests ");

    immutable string[string] env;
    immutable config = Config.none;
    immutable maxOutput = size_t.max;
    immutable workDir = "tests/functional/test_package";

    immutable result = executeShell(
        dubShellCommand("build"),
        env,
        config,
        maxOutput,
        workDir
    );

    if (result.status != 0)
        writeln(result.output);

    return result.status;
}

pure nothrow:

string dubShellCommand(string subCommand)
{
    return "dub " ~ subCommand ~ dubArch;
}

string dubArch()
{
    version (Win64)
        return " --arch=x86_64";

    else version (Win32)
        return " --arch=x86_mscoff";

    else
        return "";
}
