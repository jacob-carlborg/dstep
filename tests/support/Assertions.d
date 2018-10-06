module tests.support.Assertions;

import core.exception : AssertError;

import tests.support.DStepRunner;

struct TestFile
{
    string expected;
    string actual;
}

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
    TestFile[] filesPaths,
    string[] arguments = [],
    bool strict = false,
    string file = __FILE__,
    size_t line = __LINE__)
{
    string[] extended = arguments ~ ["-Iresources"];

    assertRunsDStep(
        filesPaths,
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
    TestFile[] testFiles,
    string[] arguments,
    bool strict,
    string file = __FILE__,
    size_t line = __LINE__)
{
    import std.algorithm : map;
    import std.array : array;
    import std.file : readText, write;
    import std.format : format;
    import std.traits : ReturnType;

    import tests.support.Util : fileExists, mismatchRegionTranslated;

    auto sep = "----------------";

    string[] outputContents;
    string command;

    ReturnType!testRunDStep result;

    try
    {
        result = testRunDStep(
            testFiles.map!(x => x.actual).array,
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

    foreach (index, testFile; testFiles)
    {
        if (fileExists(testFile.expected))
        {
            string expected = readText(testFile.expected);
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
            write(testFile.expected, outputContents[index]);
        }
    }
}
