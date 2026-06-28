module tests.support.Assertions;

import core.exception : AssertError;
import std.sumtype : SumType, match;

import tests.support.DStepRunner;

struct TestFile
{
    string expected;
    string actual;
}

struct TestDir
{
    string[] expected;
    string actual;
}

alias TestInput = SumType!(TestFile[], TestDir[]);

void assertRunsDStepCFile(
    string expectedPath,
    string cPath,
    string[] arguments = [],
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] extended = arguments ~ ["-Iresources"];

    assertRunsDStep(
        [TestFile(expectedPath, cPath)],
        extended,
        strict,
        file,
        line
    );
}

void assertRunsDStepCFiles(
    TestFile[] input,
    string[] arguments = [],
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    assertRunsDStepCInput(TestInput(input), arguments, strict, file, line);
}

void assertRunsDStepCDir(
    string[] expectedFiles,
    string actualDir,
    string[] arguments = [],
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    assertRunsDStepCInput(TestInput([TestDir(expectedFiles, actualDir)]), arguments, strict, file, line);
}

void assertRunsDStepCInput(
    TestInput input,
    string[] arguments = [],
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] extended = arguments ~ ["-Iresources"];

    assertRunsDStep(
        input,
        extended,
        strict,
        file,
        line
    );
}

void assertRunsDStepObjCFile(
    string expectedPath,
    string objCPath,
    string[] arguments = [],
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] extended = arguments ~ ["-ObjC", "-Iresources"];

    assertRunsDStep(
        [TestFile(expectedPath, objCPath)],
        extended,
        strict,
        file,
        line
    );
}

void assertIssuesWarning(
    string sourcePath,
    string[] arguments = [],
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.format : format;
    import std.algorithm : canFind;

    try
    {
        auto result = testRunDStep(
            [sourcePath],
            arguments,
            null,
            null,
            file,
            line);

        if (!canFind(result.output, "warning:"))
        {
            string message = format(
                "\nThe output doesn't contain any warnings.\nThe output:\n%s",
                result.output);

            throw new AssertError(message, file, line);
        }
    }
    catch (NoGNUStepException)
    {
        return;
    }
}

void assertRunsDStep(
    TestFile[] input,
    string[] arguments,
    bool strict,
    string file = __FILE__,
    size_t line = __LINE__)
{
    assertRunsDStep(TestInput(input), arguments, strict, file, line);
}

void assertRunsDStep(
    TestInput input,
    string[] arguments,
    bool strict,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.algorithm : map, joiner;
    import std.array : array;
    import std.file : readText, write;
    import std.format : format;
    import std.traits : ReturnType;

    import tests.support.Util : fileExists, mismatchRegionTranslated;

    auto sep = "----------------";

    string[] outputContents;
    string command;

    ReturnType!testRunDStep result;

    string[] actualInputs = input.match!(
        (TestFile[] files) => files.map!(x => x.actual).array,
        (TestDir[] dirs)   => dirs.map!(x => x.actual).array
    );

    try
    {
        result = testRunDStep(
            actualInputs,
            arguments,
            &outputContents,
            &command,
            file,
            line);
    }
    catch (NoGNUStepException)
    {
        return;
    }
    catch (NoOutputFile exception)
    {
        auto templ = q"/
Output file `%4$s` doesn't exist.
%1$s
DStep command:
%2$s
%1$s
DStep output:
%3$s/";

        auto message = format(
            templ,
            sep,
            command,
            exception.result.output,
            exception.msg);

        throw new AssertError(message, file, line);
    }


    if (result.status != 0)
    {
        auto templ = q"/
DStep failed with status %4$d.
%1$s
DStep command:
%2$s
%1$s
DStep output:
%3$s/";

        auto message = format(
            templ,
            sep,
            command,
            result.output,
            result.status);

        throw new AssertError(message, file, line);
    }

    string[] expectedOutputs = input.match!(
        (TestFile[] files) => files.map!(x => x.expected).array,
        (TestDir[] dirs)   => dirs.map!(x => x.expected).joiner.array
    );

    foreach (index, expectedPath; expectedOutputs)
    {
        if (expectedPath == "IGNORE")
            continue;

        if (fileExists(expectedPath))
        {
            string expected = readText(expectedPath);
            string actual = outputContents[index];

            auto mismatch = mismatchRegionTranslated(actual, expected, 8, strict);

            if (mismatch)
            {
                auto templ = q"/
%4$s
%1$s
DStep command:
%2$s
%1$s
DStep output:
%3$s/";

                string message = format(
                    templ,
                    sep,
                    command,
                    result.output,
                    mismatch);

                throw new AssertError(message, file, line);
            }
        }
        else
        {
            write(expectedPath, outputContents[index]);
        }
    }
}
