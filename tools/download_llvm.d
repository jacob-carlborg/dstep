#!/usr/bin/env dub
/+ dub.sdl:
    name "download_llvm"
+/
module download_llvm;

enum downloadPath = "tmp";

enum Architecture
{
    bit64 = 64,
    bit32 = 32,
    x86_64 = bit64,
    x86 = bit32,
    x86_mscoff = bit32,
}

version (Windows)
{
    enum llvmArchives = [
        64: [
            "10.0.0": "LLVM-10.0.0-win64.exe",
            "9.0.0": "LLVM-9.0.0-win64.exe"
        ],

        32: [
            "10.0.0": "LLVM-10.0.0-win32.exe",
            "9.0.0": "LLVM-9.0.0-win32.exe"
        ]
    ];

    enum llvmUrls = [
        "10.0.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-%s/%s",
        "9.0.0": "https://releases.llvm.org/%s/%s",
    ];
}

version (OSX)
{
    enum llvmArchives = [
        64: [
            "10.0.0": "clang+llvm-10.0.0-x86_64-apple-darwin.tar.xz",
            "9.0.0": "clang+llvm-9.0.0-x86_64-darwin-apple.tar.xz",
            "8.0.0": "clang+llvm-8.0.0-x86_64-apple-darwin.tar.xz",
            "6.0.0": "clang+llvm-6.0.0-x86_64-apple-darwin.tar.xz"
        ]
    ];

    enum dstepLLVMArchives = [
        64: [
            "10.0.0": "llvm-10.0.0-macos-x86_64.tar.xz"
        ]
    ];

    enum llvmUrls = [
        "10.0.0": "https://github.com/llvm/llvm-project/releases/download/llvmorg-%s/%s",
        "9.0.0": "https://releases.llvm.org/%s/%s",
        "8.0.0": "https://releases.llvm.org/%s/%s",
        "6.0.0": "https://releases.llvm.org/%s/%s"
    ];

    enum dstepLLVMUrls = [
        "10.0.0": "https://github.com/jacob-carlborg/llvm-project/releases/download/dstep-%s/%s"
    ];
}

else version (linux)
{
    enum llvmArchives = [0: ["":""]];

    enum dstepLLVMArchives = [
        64: [
            "10.0.0": "llvm-10.0.0-linux-x86_64.tar.xz"
        ]
    ];

    enum llvmUrls = ["": ""];

    enum dstepLLVMUrls = [
        "10.0.0": "https://github.com/jacob-carlborg/llvm-project/releases/download/dstep-%s/%s"
    ];
}

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

    if (!shouldInstallUsingPackageManager(config))
        extractArchive(config);
}

bool shouldInstallUsingPackageManager(Config config)
{
    version (linux)
        return !config.dstepLLVM;

    else
        return false;
}

void installUsingPackageManager()
{
    import std.format : format;

    const llvmMajorVersion = .llvmMajorVersion == "6" ? "6.0" : .llvmMajorVersion;

    executeShell("curl -L https://apt.llvm.org/llvm-snapshot.gpg.key | sudo apt-key add -");

    const repo = format!"deb https://apt.llvm.org/xenial/ llvm-toolchain-xenial-%s main"(llvmMajorVersion);
    execute("sudo", "add-apt-repository", "-y", repo);
    execute("sudo", "apt-get", "-q", "update");

    const libclangPackage = format!"libclang-%s-dev"(llvmMajorVersion);
    execute("sudo", "apt-get", "install", "-y", libclangPackage);
}

void downloadLLVM(Config config)
{
    import std.file : exists, mkdirRecurse;
    import std.net.curl : download;
    import std.path : buildPath;
    import std.stdio : writefln;

    if (shouldInstallUsingPackageManager(config))
    {
        installUsingPackageManager();
        return;
    }

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
    {
        version (OSX)
            return "4";
        else
            return "3";
    }
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

    return environment.get("LLVM_VERSION", "10.0.0");
}

string llvmMajorVersion()
{
    import std.string : split;

    return llvmVersion.split('.')[0];
}

string llvmUrl(Config config)
{
    import std.format : format;

    const baseUrls = config.dstepLLVM ? dstepLLVMUrls : llvmUrls;
    const baseUrl = baseUrls.tryGet(llvmVersion);

    return format(baseUrl, llvmVersion, llvmArchive(config));
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

string archive(string[string][int] archives, Config config)
{
    return archives.tryGet(config.architecture).tryGet(llvmVersion);
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

void execute(const string[] args ...)
{
    import std.process : spawnProcess, wait;
    import std.array : join;

    if (spawnProcess(args).wait() != 0)
        throw new Exception("Failed to execute command: " ~ args.join(' '));
}

void executeShell(string command)
{
    import std.process : spawnShell, wait;

    if (spawnShell(command).wait() != 0)
        throw new Exception("Failed to execute command: " ~ command);
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
