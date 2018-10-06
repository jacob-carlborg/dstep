#!/usr/bin/env dub
/+ dub.sdl:
    name "download_llvm"
+/
module download_llvm;

import std.stdio : println = writeln;

enum downloadPath = "tmp";

enum Architecture
{
    bit64 = 64,
    bit32 = 32,
    x86_64 = bit64,
    x86 = bit32,
    x86_mscoff = bit32,
}

enum Platform
{
    darwin,
    freebsd,
    windows,

    debian,
    fedora,
    ubuntu,
}

enum llvmArchives = [
    Platform.darwin: [
        64: "clang+llvm-%s-x86_64-apple-darwin.tar.xz"
    ],
    Platform.freebsd: [
        64: "clang+llvm-%s-amd64-unknown-freebsd10.tar.xz",
        32: "clang+llvm-%s-i386-unknown-freebsd10.tar.xz"
    ],
    Platform.debian: [
        64: "clang+llvm-%s-x86_64-linux-gnu-debian8.tar.xz"
    ],
    Platform.fedora: [
        64: "clang+llvm-%s-x86_64-fedora23.tar.xz",
        32: "clang+llvm-%s-i686-fedora23.tar.xz"
    ],
    Platform.ubuntu: [
        64: "clang+llvm-%s-x86_64-linux-gnu-ubuntu-14.04.tar.xz"
    ],
    Platform.windows: [
        64: "LLVM-%s-win64.exe",
        32: "LLVM-%s-win32.exe"
    ]
];

enum dstepLLVMArchives = [
    Platform.darwin: [
        64: "llvm-%s-macos-x86_64.tar.xz"
    ],

    Platform.ubuntu: [
        64: "llvm-%s-linux-x86_64.tar.xz"
    ]
];

struct Config
{
    bool dstepLLVM = false;
    Architecture architecture = defaultArchitecture;
}

void main(string[] args)
{
    import std.getopt : getopt;

    Config config;

    auto helpInfo = getopt(
        args,
        "dstep", &config.dstepLLVM,
        "arch", &config.architecture
    );

    downloadLLVM(config);
    extractArchive(config);
}

void downloadLLVM(Config config)
{
    import std.file : exists, mkdirRecurse;
    import std.net.curl : download;
    import std.path : buildPath;
    import std.stdio : writefln;

    auto archivePath = buildPath(downloadPath, llvmArchive(config));

    if (!exists(archivePath))
    {
        writefln("Downloading LLVM %s to %s", llvmVersion, archivePath);
        mkdirRecurse(downloadPath);
        download(llvmUrl(config), archivePath);
    }

    else
        writefln("LLVM %s already exists", llvmVersion);
}

string componentsToStrip(Config config)
{
    if (config.dstepLLVM)
        return platform == Platform.darwin ? "4" : "3";
    else
        return "1";
}

void extractArchive(Config config)
{
    import std.path : buildPath;
    import std.stdio : writefln;
    import std.file : mkdirRecurse;

    auto archivePath = buildPath(downloadPath, llvmArchive(config));
    auto targetPath = buildPath(downloadPath, "clang");

    writefln("Extracting %s to %s", archivePath, targetPath);

    mkdirRecurse(targetPath);

    version (Posix)
        execute("tar", "xf", archivePath, "-C", targetPath,
            "--strip-components=" ~ componentsToStrip(config));
    else
        execute("7z", "x", archivePath, "-y", "-o" ~ targetPath);
}

string llvmVersion()
{
    import std.process : environment;

    return environment.get("LLVM_VERSION", "4.0.0");
}

string llvmUrl(Config config)
{
    import std.array : join;

    if (config.dstepLLVM)
        return dstepLLVMUrl(config);

    return ["https://releases.llvm.org", llvmVersion, llvmArchive(config)]
        .join("/");
}

string dstepLLVMUrl(Config config)
{
    import std.format : format;

    return format("https://github.com/jacob-carlborg/llvm-svn/releases/" ~
        "download/dstep-%s/%s", llvmVersion, dstepLLVMArchive(config));
}

string llvmArchive(Config config)
{
    if (config.dstepLLVM)
        return dstepLLVMArchive(config);

    return archive(llvmArchives, config);
}

string dstepLLVMArchive(Config config)
{
    return archive(dstepLLVMArchives, config);
}

string archive(string[int][Platform] archives, Config config)
{
    import std.format : format;

    return archives
        .tryGet(platform)
        .tryGet(config.architecture)
        .format(llvmVersion);
}

Architecture defaultArchitecture()
{
    version (X86_64)
        return Architecture.bit64;
    else version (X86)
        return Architecture.bit32;
    else
        static assert("unsupported architecture");
}

Platform platform()
{
    import std.traits : EnumMembers;

    version (OSX)
        return Platform.darwin;
    else version (FreeBSD)
        return Platform.freebsd;
    else version (Windows)
        return Platform.windows;
    else version (linux)
        return linuxPlatform();
    else
        static assert("unsupported platform");
}

version (linux) Platform linuxPlatform()
{
    import std.algorithm : canFind;
    import std.process : environment;

    static struct System
    {
    static:
        import core.sys.posix.sys.utsname : utsname, uname;

        import std.exception : assumeUnique;
        import std.string : fromStringz;
        import std.uni : toLower;

        private utsname data_;

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
            return data.update.ptr.fromStringz.toLower.assumeUnique;
        }

        string nodename ()
        {
            return data.nodename.ptr.fromStringz.toLower.assumeUnique;
        }
    }

    if (System.nodename.canFind("fedora"))
        return Platform.fedora;
    else if (System.nodename.canFind("ubuntu") || System.update.canFind("ubuntu"))
        return Platform.ubuntu;
    else if (System.nodename.canFind("debian"))
        return Platform.debian;
    else if (environment.get("TRAVIS", "false") == "true")
        return Platform.ubuntu;
    else
        throw new Exception("Failed to identify the Linux platform");
}

void execute(string[] args ...)
{
    import std.process : spawnProcess, wait;
    import std.array : join;

    if (spawnProcess(args).wait() != 0)
        throw new Exception("Failed to execute command: " ~ args.join(' '));
}

inout(V) tryGet(K, V)(inout(V[K]) aa, K key)
{
    import std.format : format;

    if (auto value = key in aa)
        return *value;
    else
    {
        auto message = format("The key '%s' did not exist in the associative " ~
            "array: %s", key, aa
        );

        throw new Exception(message);
    }
}
