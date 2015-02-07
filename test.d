module test;

import std.process : execute, ProcessException;
import std.file : rmdirRecurse;

import Path = tango.io.Path;

import mambo.core._;

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
            activate(clang);
            println("Testing with libclang version ", clang.version_);
            result += test();
        }

        return result;
    }

    string workingDirectory ()
    {
        import tango.sys.Environment;

        if (wd.any)
            return wd;

        return wd = Environment.cwd.assumeUnique;
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
        return Path.join(workingDirectory, "clangs").assumeUnique;
    }

    void activate (const ref Clang clang)
    {
        auto src = Path.join(workingDirectory, clang.versionedLibclang);
        auto dest = Path.join(workingDirectory, clang.libclang);

        if (Path.exists(dest))
            Path.remove(dest);

        Path.copy(src, dest);
    }

    int test ()
    {
        auto result = execute("cucumber");

        if (result.status != 0)
            println(result.output);

        return result.status;
    }
}

struct Clang
{
    string version_;
    string baseUrl;
    string filename;

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
        enum prefix = "";
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
}

struct ClangMatrix
{
    import Path = tango.io.Path;

    private
    {
        string basePath;
        string workingDirectory;
        string clangPath_;
        immutable Clang[] clangs;
    }


    this (string workingDirectory, string basePath)
    {
        clangs = getClangs();
        this.workingDirectory = workingDirectory;
        this.basePath = basePath;
    }

    void downloadAll ()
    {
        foreach (clang ; ClangMatrix.clangs)
        {
            if (libclangExists(clang))
                continue;

            println("Downloading clang ", clang.version_);
            Path.createPath(basePath);
            download(clang);
        }
    }

    void extractAll ()
    {
        foreach (clang ; ClangMatrix.clangs)
        {
            if (libclangExists(clang))
                continue;

            println("Extracting clang ", clang.version_);
            extractArchive(clang);
            extractLibclang(clang);
            clean();
        }
    }

private:

    bool libclangExists (const ref Clang clang)
    {
        auto libclangPath = Path.join(workingDirectory, clang.versionedLibclang);
        return Path.exists(libclangPath);
    }

    void download (const ref Clang clang)
    {
        auto url = clang.baseUrl ~ clang.filename;
        auto dest = archivePath(clang.filename);

        if (!Path.exists(dest))
            Http.download(url, dest);
    }

    void extractArchive (const ref Clang clang)
    {
        auto src = archivePath(clang.filename);
        auto dest = clangPath();
        Path.createPath(dest);

        auto result = execute(["tar", "--strip-components=1", "-C", dest, "-xf", src]);

        if (result.status != 0)
            throw new ProcessException("Failed to extract archive");
    }

    string archivePath (string filename)
    {
        return Path.join(basePath, filename).assumeUnique;
    }

    string clangPath ()
    {
        if (clangPath_.any)
            return clangPath_;

        return clangPath_ = Path.join(basePath, "clang").assumeUnique;
    }

    void extractLibclang (const ref Clang clang)
    {
        auto src = Path.join(clangPath, "lib", clang.libclang);
        auto dest = Path.join(workingDirectory, clang.versionedLibclang);

        Path.copy(src, dest);
    }

    void clean ()
    {
        rmdirRecurse(clangPath);
    }

    immutable(Clang[]) getClangs ()
    {
        version (FreeBSD)
        {
            version (D_LP64)
                return [
                    Clang("3.5.0", "http://llvm.org/releases/3.5.0/", "clang+llvm-3.5.0-amd64-unknown-freebsd10.tar.xz"),
                    Clang("3.4", "http://llvm.org/releases/3.4/", "clang+llvm-3.4-amd64-unknown-freebsd9.2.tar.xz"),
                    Clang("3.3", "http://llvm.org/releases/3.3/", "clang+llvm-3.3-amd64-freebsd9.tar.xz"),
                    Clang("3.2", "http://llvm.org/releases/3.2/", "clang+llvm-3.2-amd64-freebsd9.tar.gz"),
                    Clang("3.1", "http://llvm.org/releases/3.1/", "clang+llvm-3.1-amd64-freebsd9.tar.bz2")
                ];

            else
                return [
                    Clang("3.5.0", "http://llvm.org/releases/3.5.0/", "clang+llvm-3.5.0-i386-unknown-freebsd10.tar.xz"),
                    Clang("3.4", "http://llvm.org/releases/3.4/", "clang+llvm-3.4-i386-unknown-freebsd9.2.tar.xz"),
                    Clang("3.3", "http://llvm.org/releases/3.3/", "clang+llvm-3.3-i386-freebsd9.tar.xz"),
                    Clang("3.1", "http://llvm.org/releases/3.1/", "clang+llvm-3.1-i386-freebsd9.tar.bz2")
                ];
        }

        else version (linux)
        {
            if (System.isUbuntu)
            {
                version (D_LP64)
                    return [
                        Clang("3.5.1", "http://llvm.org/releases/3.5.1/", "clang+llvm-3.5.1-x86_64-linux-gnu.tar.xz"),
                        Clang("3.5.0", "http://llvm.org/releases/3.5.0/", "clang+llvm-3.5.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz"),
                        Clang("3.4.2", "http://llvm.org/releases/3.4.2/", "clang+llvm-3.4.2-x86_64-unknown-ubuntu12.04.xz"),
                        Clang("3.4.1", "http://llvm.org/releases/3.4.1/", "clang+llvm-3.4.1-x86_64-unknown-ubuntu12.04.tar.xz"),
                        Clang("3.4", "http://llvm.org/releases/3.4/", "clang+llvm-3.4-x86_64-unknown-ubuntu12.04.tar.xz"),
                        Clang("3.3", "http://llvm.org/releases/3.3/", "clang+llvm-3.3-amd64-Ubuntu-12.04.2.tar.gz"),
                        Clang("3.2", "http://llvm.org/releases/3.2/", "clang+llvm-3.2-x86_64-linux-ubuntu-12.04.tar.gz"),
                        Clang("3.1", "http://llvm.org/releases/3.1/", "clang+llvm-3.1-x86_64-linux-ubuntu_12.04.tar.gz")
                    ];
                else
                    return [
                        Clang("3.2", "http://llvm.org/releases/3.2/", "clang+llvm-3.2-x86-linux-ubuntu-12.04.tar.gz"),
                        Clang("3.1", "http://llvm.org/releases/3.1/", "clang+llvm-3.1-x86-linux-ubuntu_12.04.tar.gz")
                    ];
            }

            else if (System.isFedora)
            {
                version (D_LP64)
                    return [
                        Clang("3.5.1", "http://llvm.org/releases/3.5.1/", "clang+llvm-3.5.1-x86_64-fedora20.tar.xz"),
                        Clang("3.5.0", "http://llvm.org/releases/3.5.0/", "clang+llvm-3.5.0-x86_64-fedora20.tar.xz"),
                        Clang("3.4", "http://llvm.org/releases/3.4/", "clang+llvm-3.4-x86_64-fedora19.tar.gz"),
                        Clang("3.3", "http://llvm.org/releases/3.3/", "clang+llvm-3.3-x86_64-fedora18.tar.bz2")
                    ];
                else
                    return [
                        Clang("3.5.1", "http://llvm.org/releases/3.5.1/", "clang+llvm-3.5.1-i686-fedora20.tar.xz"),
                        Clang("3.5.0", "http://llvm.org/releases/3.5.0/", "clang+llvm-3.5.0-i686-fedora20.tar.xz"),
                        Clang("3.4.2", "http://llvm.org/releases/3.4.2/", "clang+llvm-3.4.2-i686-fedora20.xz"),
                        Clang("3.4.1", "http://llvm.org/releases/3.4.1/", "clang+llvm-3.4.1-i686-fedora20.tar.xz"),
                        Clang("3.4", "http://llvm.org/releases/3.4/", "clang+llvm-3.4-i686-fedora19.tar.gz"),
                        Clang("3.3", "http://llvm.org/releases/3.3/", "clang+llvm-3.3-i686-fedora18.tar.bz2")
                    ];
            }

            else
                throw new Error("Current Linux distribution '" ~ System.update ~ "' is not supported");
        }

        else version (OSX)
        {
            version (D_LP64)
                return [
                    Clang("3.5.0", "http://llvm.org/releases/3.5.0/", "clang+llvm-3.5.0-macosx-apple-darwin.tar.xz"),
                    Clang("3.4.2", "http://llvm.org/releases/3.4.2/", "clang+llvm-3.4.2-x86_64-apple-darwin10.9.xz"),
                    // Clang("3.4.1", "http://llvm.org/releases/3.4.1/", "clang+llvm-3.4.1-x86_64-apple-darwin10.9.tar.xz"),
                    // Clang("3.4", "http://llvm.org/releases/3.4/", "clang+llvm-3.4-x86_64-apple-darwin10.9.tar.gz"),
                    Clang("3.3", "http://llvm.org/releases/3.3/", "clang+llvm-3.3-x86_64-apple-darwin12.tar.gz"),
                    Clang("3.2", "http://llvm.org/releases/3.2/", "clang+llvm-3.2-x86_64-apple-darwin11.tar.gz"),
                    Clang("3.1", "http://llvm.org/releases/3.1/", "clang+llvm-3.1-x86_64-apple-darwin11.tar.gz")
                ];

            else
                static assert(false, "Only 64bit versions of OS X are supported");
        }

        else version (Windows)
        {
            return [
                Clang("3.5.0", "http://llvm.org/releases/3.5.0/", "LLVM-3.5.0-win32.exe"),
                Clang("3.4.1", "http://llvm.org/releases/3.4.1/", "LLVM-3.4.1-win32.exe"),
                Clang("3.4", "http://llvm.org/releases/3.4/", "LLVM-3.4-win32.exe")
            ];
        }

        else
            static assert(false, "Unsupported platform");
    }
}

struct System
{
static:

version (linux):

    private string update_;

    bool isFedora ()
    {
        return update.contains("fedora");
    }

    bool isUbuntu ()
    {
        return update.contains("ubuntu");
    }

    string update ()
    {
        import core.sys.posix.sys.utsname;
        import std.exception;

        if (update_.any)
            return update_;

        utsname data;
        errnoEnforce(!uname(&data));

        return update_ = data.update.ptr.toString.toLower;
    }
}

struct Http
{
    import tango.io.device.File;
    import tango.io.model.IConduit;
    import tango.net.device.Socket;
    import tango.net.http.HttpGet;
    import tango.net.http.HttpConst;

static:

    void download (string url, string destination, float timeout = 30f, ProgressHandler progress = new CliProgressHandler)
    {
        auto data = download(url, timeout, progress);
        writeFile(data, destination);
    }

    void[] download (string url, float timeout = 30f, ProgressHandler progress = new CliProgressHandler)
    {
        scope page = new HttpGet(url);
        page.setTimeout(timeout);
        auto buffer = page.open;

        checkPageStatus(page, url);

        auto contentLength = page.getResponseHeaders.getInt(HttpHeader.ContentLength);

        enum width = 40;
        int bytesLeft = contentLength;
        int chunkSize = bytesLeft / width;

        progress.start(contentLength, chunkSize, width);

        while (bytesLeft > 0)
        {
            buffer.load(chunkSize > bytesLeft ? bytesLeft : chunkSize);
            bytesLeft -= chunkSize;
            progress(bytesLeft);
        }

        progress.end();

        return buffer.slice;
    }

    bool exists (string url)
    {
        scope resource = new HttpGet(url);
        resource.open;

        return resource.isResponseOK;
    }

private:

    void checkPageStatus (HttpGet page, string url)
    {
        import tango.core.Exception;

        if (page.getStatus == 404)
            throw new IOException(format(`The resource with URL "{}" could not be found.`, url));

        else if (!page.isResponseOK)
            throw new IOException(format(`An unexpected error occurred. The resource "{}" responded with the message "{}" and the status code {}.`, url, page.getResponse.getReason, page.getResponse.getStatus));
    }

    void writeFile (void[] data, string filename)
    {
        scope file = new File(filename, File.WriteCreate);
        file.write(data);
    }
}

abstract class ProgressHandler
{
    void start (int length, int chunkSize, int width);
    void opCall (int bytesLeft);
    void end ();
}

class CliProgressHandler : ProgressHandler
{
    private
    {
        int num;
        int width;
        int chunkSize;
        int contentLength;

        version (Posix)
            enum
            {
                clearLine = "\033[1K", // clear backwards
                saveCursor = "\0337",
                restoreCursor = "\0338"
            }

        else
            enum
            {
                clearLine = "\r",
                saveCursor = "",
                restoreCursor = ""
            }
    }

    override void start (int contentLength, int chunkSize, int width)
    {
        this.chunkSize = chunkSize;
        this.contentLength = contentLength;
        this.width = width;
        this.num = width;

        print(saveCursor);
    }

    override void opCall (int bytesLeft)
    {
        int i = 0;

        print(clearLine ~ restoreCursor ~ saveCursor);
        print("[");

        for ( ; i < (width - num); i++)
            print("=");

        print(">");

        for ( ; i < width; i++)
            print(" ");

        print("]");
        print(format(" {}/{} KB", (contentLength - bytesLeft) / 1024, contentLength / 1024).assumeUnique);

        num--;
    }

    override void end ()
    {
        println(restoreCursor);
        println();
    }
}
