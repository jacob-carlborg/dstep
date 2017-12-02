module tests.support.Util;

bool fileExists(string path)
{
    import std.file : exists, isFile;
    return exists(path) && isFile(path);
}

string mismatchRegion(
    string expected,
    string actual,
    size_t margin,
    bool strict,
    string prefix = "<<<<<<< expected",
    string interfix = "=======",
    string suffix = ">>>>>>> actual")
{
    import std.algorithm.iteration : splitter;
    import std.range : empty;
    import std.string : lineSplitter, stripRight, strip;
    import std.algorithm.comparison : min;

    if (!strict)
    {
        expected = stripRight(expected);
        actual = stripRight(actual);
    }

    string[] Q;
    size_t q = 0;
    size_t p = 0;
    Q.length = margin;

    size_t line = 0;

    auto aItr = lineSplitter(expected);
    auto bItr = lineSplitter(actual);

    while (!aItr.empty && !bItr.empty)
    {
        if (aItr.front != bItr.front)
            break;

        Q[p] = aItr.front;

        q = min(q + 1, margin);
        p = (p + 1) % margin;

        aItr.popFront();
        bItr.popFront();

        ++line;
    }

    if (strict && expected.length != actual.length && aItr.empty && bItr.empty)
    {
        if (expected.length < actual.length)
            bItr = lineSplitter("\n");
        else
            aItr = lineSplitter("\n");
    }

    margin = expected.strip.empty
        || actual.strip.empty
        ? size_t.max : margin;

    if (!aItr.empty || !bItr.empty)
    {
        import std.array : Appender;
        import std.conv : to;

        auto result = Appender!string();

        auto l = line - q;

        result.put(prefix);
        result.put("\n");

        foreach (i; 0 .. q)
        {
            result.put(to!string(l + i));
            result.put(": ");
            result.put(Q[(p + i) % q]);
            result.put("\n");
        }

        for (size_t i = 0; i <= margin && !aItr.empty; ++i)
        {
            result.put(to!string(line + i));
            result.put("> ");
            result.put(aItr.front);
            result.put("\n");
            aItr.popFront();
        }

        result.put(interfix);
        result.put("\n");

        foreach (i; 0 .. q)
        {
            result.put(to!string(l + i));
            result.put(": ");
            result.put(Q[(p + i) % q]);
            result.put("\n");
        }

        for (size_t i = 0; i <= margin && !bItr.empty; ++i)
        {
            result.put(to!string(line + i));
            result.put("> ");
            result.put(bItr.front);
            result.put("\n");
            bItr.popFront();
        }

        result.put(suffix);
        result.put("\n");

        return result.data;
    }

    return null;
}

string mismatchRegionTranslated(
    string translated,
    string expected,
    size_t margin,
    bool strict)
{
    return mismatchRegion(
        translated,
        expected,
        margin,
        strict,
        "Translated code doesn't match expected.\n<<<<<<< translated",
        "=======",
        ">>>>>>> expected");
}

unittest
{
    import core.exception : AssertError;

    void assertMismatchRegion(
        string expected,
        string a,
        string b,
        bool strict = false,
        size_t margin = 2,
        string file = __FILE__,
        size_t line = __LINE__)
    {
        import std.format;

        auto actual = mismatchRegion(a, b, margin, strict);

        if (expected != actual)
        {
            auto templ = "\nExpected:\n%s\nActual:\n%s\n";

            string message = format(templ, expected, actual);

            throw new AssertError(message, file, line);
        }
    }

    assertMismatchRegion(null, "", "");

    assertMismatchRegion(null, "foo", "foo");

    assertMismatchRegion(q"X
<<<<<<< expected
0: foo
1> bar
=======
0: foo
1> baz
>>>>>>> actual
X", "foo\nbar", "foo\nbaz");

    assertMismatchRegion(q"X
<<<<<<< expected
0: foo
=======
0: foo
1> baz
>>>>>>> actual
X", "foo", "foo\nbaz");

    assertMismatchRegion(q"X
<<<<<<< expected
1: bar
2: baz
3> quuux
4> yada
5> yada
=======
1: bar
2: baz
3> quux
4> yada
5> yada
>>>>>>> actual
X", "foo\nbar\nbaz\nquuux\nyada\nyada\nyada\nlast", "foo\nbar\nbaz\nquux\nyada\nyada\nyada\nlast");

    assertMismatchRegion(q"X
<<<<<<< expected
1: bar
2: baz
3> quuux
4> yada
5> yada
=======
1: bar
2: baz
3> quuuux
4> yada
5> yada
>>>>>>> actual
X", "foo\nbar\nbaz\nquuux\nyada\nyada\nyada\nlast", "foo\nbar\nbaz\nquuuux\nyada\nyada\nyada\nlast");

    assertMismatchRegion(
        "<<<<<<< expected\n0: foo\n1> \n=======\n0: foo\n>>>>>>> actual\n",
        "foo\n",
        "foo",
        true);
}
