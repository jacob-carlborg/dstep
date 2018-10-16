import std.stdio : writeln;
import clang.Util : clangVersionString;

void main(string[] args)
{
    writeln("with ", clangVersionString);
}
