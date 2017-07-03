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
        auto matrix = setup();

        foreach (const clang ; matrix.clangs)
        {
            import std.string;

            activate(clang);

            auto output = execute(["./bin/dstep", "--clang-version"]);

            writeln("Testing with ", strip(output.output));
            result += unitTest();
            stdout.flush();
        }

        return result;
    }

    string workingDirectory ()
    {
        if (wd.length)
            return wd;

        return wd = getcwd();
    }

    auto setup ()
    {
        auto matrix = ClangMatrix(workingDirectory, clangBasePath);

        matrix.downloadAll;
        matrix.extractAll;

        return matrix;
    }

    string clangBasePath ()
    {
        return buildNormalizedPath(workingDirectory, "clangs");
    }

    void activate (const Clang clang)
    {
        version (Windows)
        {
            auto src = buildNormalizedPath(workingDirectory, clang.versionedLibclang);
            auto dest = buildNormalizedPath(workingDirectory, clang.libclang);

            if (exists(dest))
                remove(dest);

            copy(src, dest);
        }

        else
        {
            execute(["./configure", "--llvm-path", clang.llvmLibPath]);
            build();
        }
    }

    int unitTest ()
    {
        writeln("Running unit tests ");

        version (Win64)
            auto result = executeShell("dub test --arch=x86_64");
        else
            auto result = executeShell("dub test");

        if (result.status != 0)
            writeln(result.output);

        return result.status;
    }

    void build ()
    {
        version (Win64)
            auto result = executeShell("dub build --arch=x86_64");
        else
            auto result = executeShell("dub build");

        if (result.status != 0)
        {
            writeln(result.output);
            throw new Exception("Failed to build DStep");
        }
    }
}

struct Clang
{
    string version_;
    string baseUrl;
    string filename;
    string basePath;

    version (linux)
    {
        enum extension = ".so";
        enum prefix = "lib";
    }

    else version (OSX)
    {
        enum extension = ".dylib";
        enum prefix = "lib";
    }

    else version (Windows)
    {
        enum extension = ".dll";
        enum prefix = "lib";
    }

    else version (FreeBSD)
    {
        enum extension = ".so";
        enum prefix = "lib";
    }

    else
        static assert(false, "Unsupported platform");

    string libclang () const
    {
        return Clang.prefix ~ "clang" ~ Clang.extension;
    }

    string versionedLibclang () const
    {
        return Clang.prefix ~ "clang-" ~ version_ ~ Clang.extension;
    }

    string archivePath () const
    {
        return buildNormalizedPath(basePath, filename);
    }

    string extractionPath() const
    {
        version (Posix)
            return archivePath.stripExtension.stripExtension;
        else
            return buildNormalizedPath(basePath, "clang");
    }

    string llvmLibPath() const
    {
        version (Posix)
            enum libPath = "lib";
        else
            enum libPath = "bin";

        return buildNormalizedPath(extractionPath, libPath);
    }
}

struct ClangMatrix
{
    private
    {
        string basePath;
        string workingDirectory;
        string clangPath_;
        immutable Clang[] clangs;
    }

    this (string workingDirectory, string basePath)
    {
        this.workingDirectory = workingDirectory;
        this.basePath = basePath;
        clangs = getClangs();
    }

    void downloadAll ()
    {
        mkdirRecurse(basePath);

        foreach (clang ; ClangMatrix.clangs)
        {
            stdout.flush();
            download(clang);
        }
    }

    void extractAll ()
    {
        foreach (clang ; ClangMatrix.clangs)
        {
            extractArchive(clang);
            extractLibclang(clang);
            stdout.flush();
        }
    }

private:

    void download (const ref Clang clang)
    {
        import std.file : write;
        import HttpClient : getBinary;

        auto dest = clang.archivePath;

        if (exists(dest))
            return;

        auto url = clang.baseUrl ~ clang.filename;

        writeln("Downloading clang ", clang.version_);
        write(dest, getBinary(url));
    }

    void extractArchive (const ref Clang clang)
    {
        auto src = clang.archivePath;
        auto dest = clang.extractionPath;

        if (exists(dest))
            return;

        writeln("Extracting clang ", clang.version_);
        mkdirRecurse(dest);

        version (Posix)
            auto result = execute(["tar", "--strip-components=1", "-C", dest, "-xf", src]);
        else
            auto result = execute(["7z", "x", src, "-y", format("-o%s", dest)]);

        if (result.status != 0)
            throw new ProcessException("Failed to extract archive");
    }

    void extractLibclang (const ref Clang clang)
    {
        version (Windows)
        {
            auto src = buildNormalizedPath(clang.extractionPath, "bin", clang.libclang);
            auto dest = buildNormalizedPath(workingDirectory, clang.versionedLibclang);

            copy(src, dest);
        }
    }

    Clang clang(string version_, string baseUrl, string filename)
    {
        return Clang(version_, baseUrl, filename, basePath);
    }

    immutable(Clang[]) getClangs ()
    {
        version (Posix)
            void unsupported()
            {
                throw new Exception("Current version of '" ~ System.update ~ "' is not supported");
            }

        version (FreeBSD)
        {
            version (D_LP64)
                return [
                    clang("3.8.0", "http://releases.llvm.org/3.8.0/", "clang+llvm-3.8.0-amd64-unknown-freebsd10.tar.xz")
                ];

            else
                return [
                    clang("3.8.0", "http://releases.llvm.org/3.8.0/", "clang+llvm-3.8.0-i386-unknown-freebsd10.tar.xz")
                ];
        }

        else version (linux)
        {
            if (System.isUbuntu || System.isTravis)
            {
                version (D_LP64)
                    return [
                        clang("3.8.0", "http://releases.llvm.org/3.8.0/", "clang+llvm-3.8.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz")
                    ];
                else
                    unsupported();
            }

            else if (System.isDebian)
            {
                version (D_LP64)
                    return [
                        clang("3.8.0", "http://releases.llvm.org/3.8.0/", "clang+llvm-3.8.0-x86_64-linux-gnu-debian8.tar.xz")
                    ];
                else
                    unsupported();
            }

            else if (System.isFedora)
            {
                version (D_LP64)
                    return [
                        clang("3.8.0", "http://releases.llvm.org/3.8.0/", "clang+llvm-3.8.0-x86_64-fedora23.tar.xz")
                    ];
                else
                    return [
                        clang("3.8.0", "http://releases.llvm.org/3.8.0/", "clang+llvm-3.8.0-i686-fedora23.tar.xz")
                    ];
            }

            else
                unsupported();

            return null;
        }

        else version (OSX)
        {
            version (D_LP64)
            {
                return [
                    clang("3.8.0", "http://releases.llvm.org/3.8.0/", "clang+llvm-3.8.0-x86_64-apple-darwin.tar.xz")
                ];
            }

            else
                static assert(false, "Only 64bit versions of OS X are supported");
        }

        else version (Win32)
        {
            return [
                clang("3.8.0", "http://releases.llvm.org/3.8.0/", "LLVM-3.8.0-win32.exe")
            ];
        }

        else version (Win64)
        {
            return [
                clang("3.8.0", "http://releases.llvm.org/3.8.0/", "LLVM-3.8.0-win64.exe"),
            ];
        }

        else
            static assert(false, "Unsupported platform");
    }
}

struct System
{
static:

    version (D_LP64)
        bool isTravis ()
        {
            return environment.get("TRAVIS", "false") == "true";
        }

    else
        bool isTravis ()
        {
            return false;
        }

version (Posix):

    import core.sys.posix.sys.utsname;

    private
    {
        utsname data_;
        string update_;
        string nodename_;
    }

    bool isFedora ()
    {
        return nodename.canFind("fedora");
    }

    bool isUbuntu ()
    {
        return nodename.canFind("ubuntu") || update.canFind("ubuntu");
    }

    bool isDebian ()
    {
        return nodename.canFind("debian");
    }

    private utsname data()
    {
        import std.exception;

        if (data_ != data_.init)
            return data_;

        errnoEnforce(!uname(&data_));
        return data_;
    }

    string update ()
    {
        if (update_.length)
            return update_;

        return update_ = data.update.ptr.fromStringz.toLower.assumeUnique;
    }

    string nodename ()
    {
        if (nodename_.length)
            return nodename_;

        return nodename_ = data.nodename.ptr.fromStringz.toLower.assumeUnique;
    }
}
