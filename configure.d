/**
 * This file implements a configuration script that will setup the correct flags
 * to link with libclang.
 *
 * The script will try to automatically detect the location of libclang by
 * searching through a number of preset library search paths for different
 * platforms.
 *
 * If the script fails to find libclang or fails to find the correct version,
 * this script provides a flag,`--llvm-config`, which can be used by manually
 * executing this script (`./configure`) and specifying the path to the LLVM
 * configuration binary, `llvm-config`. The LLVM configuration binary will then
 * be used to find the location of libclang.
 *
 * The result of invoking this configuration script is a file,
 * `linker_flags.txt`, which will be created. This file contains the necessary
 * linker flags which will be read by the linker when building DStep.
 *
 * This script is only intended to be used on the Posix platforms.
 */
module configure;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.format;
import std.getopt;
import std.path;
import std.process;
import std.range;
import std.string;
import std.uni;
import std.traits;

version (Posix)
{
    version (OSX) {}
    else version (linux) {}
    else version (FreeBSD) {}
    else
        static assert("The current platform is not supported");
}
else
    static assert("This script should only be run on Posix platforms");

/**
 * The options of the application.
 *
 * When parsing the command line arguments, these fields will be set.
 */
struct Options
{
    /// Print extra information.
    bool verbose = true;

    /// Indicates if help/usage information was requested.
    bool help = false;

    /// The specified path to the LLVM/Clang root directory.
    string llvmPath;

    /**
     * The specified path to the location of additional libraries, like
     * `ncurses` or `tinfo`, that needs to linked when linking libclang
     * statically.
     */
    string additionalLibPath;

    /// Indicates if libclang should be statically or dynamically linked.
    bool staticallyLinkClang = false;

    /**
     * Indicates if the whole binary, including the C standard library, should
     * be statically linked.
     */
    bool staticallyLinkBinary = false;

    /// The path to the LLVM/Clang library directory.
    string llvmLibPath ()
    {
        auto libPath = llvmconfigGetOpts("--libdir", llvmPath);

        if (libPath)
            return libPath;

        return llvmPath.empty ? "" : buildPath(llvmPath, "lib");
    }
}

/**
 * Get the output of llvm-config program.
 *
 * Params:
 *  cmdOptions = the arguments to parse. If multiple, pass a string array
 *  llvmPath = optional LLVM root path to look for the executable
 *
 * Return: the command output stripping newlines, otherwise `null`
 */
string llvmconfigGetOpts(T)(T cmdOptions, string llvmPath = "")
    if (is(T == string) || is(T == string[]))
{
    import std.ascii : newline;

    string binDir = llvmPath.empty ? "" : buildPath(llvmPath, "bin");
    string llvmconfig = buildPath(binDir, DefaultConfig.llvmConfigExecutable);

    static if (is(T == string))
        string[] options = [cmdOptions];
    else
        alias options = cmdOptions;

    try
    {
        auto run = execute(llvmconfig ~ options);

        if (run.status == 0)
            return run.output.strip(newline);
    }
    catch(ProcessException) {}

    return null;
}

/// This struct contains the name and filename of a library.
struct LibraryName
{
    /**
     * The name of the library.
     *
     * Used in error message and similar.
     */
    string name;

    /// The filename of the library.
    string filename;
}

/// Default configuration and paths.
struct DefaultConfig
{
static:

    version (D_Ddoc)
    {
        /// The name of the Clang dynamic library.
        enum clangLib = "";

        /**
         * A list of default paths where to look for the LLVM and Clang
         * libraries.
         */
        immutable string[] llvmLibPaths = [];

        /**
         * A list of default paths where to look for additional libraries.
         *
         * Thes are libraries that are not part of LLVM or Clang which are used
         * when statically linking libclang.
         */
        immutable string[] additionalLibPaths = [];

        /**
         * The name of the additional static library, like `ncurses` or `tinfo`.
         *
         * Used when statically linking libclang.
         */
        enum additionalLib = LibraryName();

        /**
         * The name of the C++ standard library.
         *
         * Used when statically linking libclang.
         */
        enum cppLib = "c++";
    }

    else version (OSX)
    {
        enum clangLib = "libclang.dylib";

        enum standardPaths = [
            "/usr/local/lib",
            "/usr/lib"
        ];

        immutable llvmLibPaths = [
            "/opt/local/libexec/llvm-4.0/lib", // MacPorts
            "/usr/local/opt/llvm40/lib", // Homebrew
            "/opt/local/libexec/llvm-3.9/lib", // MacPorts
            "/usr/local/opt/llvm39/lib", // Homebrew
            "/opt/local/libexec/llvm-3.8/lib", // MacPorts
            "/usr/local/opt/llvm38/lib", // Homebrew
            "/opt/local/libexec/llvm-3.7/lib", // MacPorts
            "/usr/local/opt/llvm37/lib" // Homebrew
        ] ~ standardPaths;

        immutable additionalLibPaths = [
            "/opt/local/lib",
            "/usr/local/opt/ncurses/lib" // the brew ncurses formula is a keg-only
        ] ~ standardPaths;

        enum additionalLib = LibraryName("ncurses", "libncurses.a");
        enum cppLib = "c++";
    }

    else version (linux)
    {
        enum clangLib = "libclang.so";

        enum standardPaths = [
            "/usr/lib",
            "/usr/local/lib",
            "/usr/lib/x86_64-linux-gnu", // Debian
            "/usr/lib64", // Fedora
            "/usr/lib32" // Fedora
        ];

        immutable llvmLibPaths = [
            "/usr/lib/llvm-4.0/lib", // Debian
            "/usr/lib/llvm-3.9/lib", // Debian
            "/usr/lib/llvm-3.8/lib", // Debian
            "/usr/lib/llvm-3.7/lib", // Debian
            "/usr/lib64/llvm", // CentOS
            "/usr/lib32/llvm" // CentOS
        ] ~ standardPaths;

        immutable additionalLibPaths = standardPaths;

        enum additionalLib = LibraryName("tinfo", "libtinfo.a");
        enum cppLib = "stdc++";
    }

    else version (FreeBSD)
    {
        enum clangLib = "libclang.so";

        enum standardPaths = [
            "/usr/lib",
            "/usr/local/lib"
        ];

        immutable llvmLibPaths = [
            "/usr/local/llvm80/lib",
            "/usr/local/llvm70/lib",
            "/usr/local/llvm60/lib",
            "/usr/local/llvm50/lib",
        ] ~ standardPaths;

        immutable additionalLibPaths = standardPaths;

        enum additionalLib = LibraryName("ncurses", "libncurses.a");
        enum cppLib = "c++";
    }

    else
        static assert(false, "Unsupported platform");

    /// The name of the LLVM configure binary.
    enum llvmConfigExecutable = "llvm-config";
}

/**
 * This class represents a path to a file, like a library or an executable.
 *
 * It's the abstract base class for the `LibraryPath` and `LLVMConfigPath`
 * subclasses.
 */
class Path
{
    private
    {
        /**
         * The name of the file this path represents.
         *
         * This is a name for the file that is used in error messages.
         */
        string name;

        /**
         * A set of standard paths to which to search for the file this path
         * represents.
         */
        const(string)[] standardPaths;

        /**
         * The custom path that was specified when invoking this configuration
         * script, or `null` if no custom path was specified.
         */
        string specifiedPath;

        /// The actual file to look for in `standardPaths` and `specifiedPath`.
        string fileToCheck;

        /// Local cache for the full path to the file.
        string path_;
    }

    alias path this;

    /**
     * Constructs a new instance of this class.
     *
     * Params:
     *  name = the name of the file this path represents
     *
     *  standardPaths = a set of standard paths to which to search for the file
     *      this path represents
     *
     *  specifiedPath = the custom path that was specified when invoking this
     *      configuration script, or `null` if no custom path was specified
     *
     *  fileToCheck = the actual file to look for in `standardPaths` and
     *      `specifiedPath`
     */
    this(string name, const(string)[] standardPaths,
        string specifiedPath, string fileToCheck)
    {
        this.name = name;
        this.standardPaths = standardPaths;
        this.specifiedPath = specifiedPath;
        this.fileToCheck = fileToCheck;
    }

    /**
     * Returns the full path to the file this path represents as a string.
     *
     * If `specifiedPath` is non-empty, `fileToCheck` will be searched for in
     * `specifiedPath`. Otherwise `fileToCheck` will be searched for in
     * `standardPaths`.
     *
     * Returns: the full path to the file this path represents
     */
    string path()
    {
        if (path_.ptr)
            return path_;

        return path_ = specifiedPath.empty ? standardPath : customPath;
    }

    override string toString()
    {
        return path;
    }

    /**
     * Returns the full path of `fileToCheck` by searching in `standardPaths`.
     *
     * Returns: the full path of `fileToCheck` by searching in `standardPaths`
     *
     * Throws: an `Exception` if `fileToCheck` cannot be found in any of the
     *  paths in `standardPath`
     */
    string standardPath()
    {
        auto errorMessage = format("Could not find %s in any of the standard " ~
            "paths for %s: \n%s\nPlease specify a path manually using " ~
            "'./configure --%s-path=<path>'.",
            fileToCheck, name, standardPaths.join('\n'), name.toLower
        );

        auto result = standardPaths.
            find!(exists).
            find!(e => e.buildPath(fileToCheck).exists);

        enforce(!result.empty, errorMessage);

        return result.front.absolutePath;
    }

private:

    /**
     * Returns the full path of `fileToCheck` by searching in `specifiedPath`
     * and the `PATH` environment variable.
     *
     * If `fileToCheck` cannot be found in `specifiedPath` it will search for
     * `fileToCheck` in the `PATH` environment variable. If that fails, an
     * exception is thrown.
     *
     * Returns: the full path of `fileToCheck`
     *
     * Throws: an `Exception` if `fileToCheck` cannot be found in
     *  `specifiedPath` or the `PATH` environment variable
     */
    string customPath()
    {
        auto path = specifiedPath.asAbsolutePath.asNormalizedPath.to!string;

        auto errorMessage = format("The specified library %s in path '%s' " ~
            "does not exist.", name, path);

        if (path.exists)
            return path;

        path = searchPath(specifiedPath);
        enforce(path.exists, errorMessage);

        return path;
    }
}

/**
 * This mixin template contains shared logic to generate the actual
 * configuration.
 */
mixin template BaseConfigurator()
{
    private
    {
        /// The name of the file where the configuration is written.
        enum configPath = "linker_flags.txt";

        /// The options that were the result of parsing the command line flags.
        Options options;

        /// The default configuration.
        DefaultConfig defaultConfig;

        /// The LLVM/Clang library path.
        Path llvmLibPath;
    }

    /**
     * Initializes the receiver with the given arguments. This method acts as
     * the shared constructor.
     *
     * Params:
     *  options = the options
     *  defaultConfig = the default configuration
     */
    void initialize(Options options, DefaultConfig defaultConfig)
    {
        this.options = options;
        this.defaultConfig = defaultConfig;

        llvmLibPath = new Path(
            "llvm",
            defaultConfig.llvmLibPaths,
            options.llvmLibPath,
            defaultConfig.clangLib
        );
    }

private:

    /**
     * Writes given configuration to the config file.
     *
     * Params:
     *  config = the configuration to write, that is, the linker flags
     */
    void writeConfig(string config)
    {
        write(configPath, config);
    }

    /// Returns: the configuration, that is, the linker flags.
    string config()
    {
        return flags.filter!(e => !e.empty).join("\n") ~ '\n';
    }
}

/**
 * This struct contains the logic for generating the configuration for static
 * linking.
 */
struct StaticConfigurator
{
    mixin BaseConfigurator;

    private
    {
        version (D_Ddoc)
        {
            /**
             * Contains the `--start-group` flag on non-macOS platforms.
             *
             * Used on non-macOS platforms to group the LLVM and Clang
             * libraries to be searched repeatedly to resolve undefined symbols.
             */
            enum startGroupFlag = "";

            /**
             * Contains the `--end-group` flag on non-macOS platforms.
             *
             * Used on non-macOS platforms to group the LLVM and Clang
             * libraries to be searched repeatedly to resolve undefined symbols.
             */
            enum endGroupFlag = "";
        }

        else version (OSX)
        {
            enum startGroupFlag = "".only;
            enum endGroupFlag = "".only;
        }

        else
        {
            enum startGroupFlag = "--start-group".only;
            enum endGroupFlag = "-Wl,--end-group".only;
        }

        /// Local cache for the additional library path.
        Path additionalLibPath;
    }

    /**
     * Constructs a new instance of this struct with the given arguments.
     *
     * Params:
     *  options = the options
     *  defaultConfig = the default configuration
     */
    this(Options options, DefaultConfig defaultConfig)
    {
        initialize(options, defaultConfig);

        additionalLibPath = new Path(defaultConfig.additionalLib.name,
            DefaultConfig.additionalLibPaths,
            options.additionalLibPath, defaultConfig.additionalLib.filename);
    }

    /**
     * Generates the actual configuration.
     *
     * This will locate all required libraries, build a set of linker flags and
     * write the result to the configuration file.
     */
    void generateConfig()
    {
        enforceLibrariesExist(
            DefaultConfig.additionalLib.name,
            additionalLibPath,
            DefaultConfig.additionalLib.filename
        );

        writeConfig(config);
    }

private:

    /// Return: a range of all the necessary linker flags.
    auto flags()
    {
        return chain(
            startGroupFlag,
            libclangFlags,
            llvmFlags,
            endGroupFlag,
            additionalLibFlags,
            cppFlags,
            extraFlags
        );
    }

    /**
     * Returns: a range of linker flags necessary to link with the standard C++
     *  library.
     */
    auto cppFlags()
    {
        return format("-l%s", DefaultConfig.cppLib).only;
    }

    /**
     * Returns: a range of linker flags necessary to link with the ncurses
     *  library.
     */
    auto additionalLibFlags()
    {
        return additionalLibPath
            .buildPath(DefaultConfig.additionalLib.filename)
            .only;
    }

    /**
     * Returns: a range of linker flags necessary to link with the LLVM
     *  libraries.
     */
    auto llvmFlags()
    {
        const result = dirEntries(llvmLibPath, "libLLVM*.a", SpanMode.shallow)
            .map!(e => e.name)
            .array;

        const findAllSymbolsPath = llvmLibPath.buildPath("libfindAllSymbols.a");

        return findAllSymbolsPath.exists ? result ~ findAllSymbolsPath : result;
    }

    /**
     * Returns: a range of linker flags necessary to link with the Clang
     *  libraries.
     */
    auto libclangFlags()
    {
        return dirEntries(llvmLibPath, "libclang*.a", SpanMode.shallow);
    }

    auto extraFlags()
    {
         return (options.staticallyLinkBinary ? "-static" : "").only;
    }
}

/**
 * This struct contains the logic for generating the configuration for dynamic
 * linking.
 */
struct DynamicConfigurator
{
    mixin BaseConfigurator;

    /**
     * Constructs a new instance of this struct with the given arguments.
     *
     * Params:
     *  options = the options
     *  defaultConfig = the default configuration
     */
    this(Options options, DefaultConfig defaultConfig)
    {
        initialize(options, defaultConfig);
    }

    /**
     * Generates the actual configuration.
     *
     * This will locate all required libraries, build a set of linker flags and
     * write the result to the configuration file.
     */
    void generateConfig()
    {
        enforceLibrariesExist("libclang", llvmLibPath, DefaultConfig.clangLib);

        writeConfig(config);
    }

private:

    /// Return: a range of all the necessary linker flags.
    auto flags()
    {
        return format("-L%1$s\n-lclang\n-Xlinker -rpath %1$s", llvmLibPath)
            .only;
    }
}

/// The main entry point of this script.
void main(string[] args)
{
    auto options = parseArguments(args);

    if (!options.help)
    {
        if (options.staticallyLinkClang)
            StaticConfigurator(options, DefaultConfig()).generateConfig();
        else
            DynamicConfigurator(options, DefaultConfig()).generateConfig();
    }
}

private:

/**
 * Parses the command line arguments given to the application.
 *
 * Params:
 *  args = the command line arguments to parse
 *
 * Returns: the options set while parsing the arguments
 */
Options parseArguments(string[] args)
{
    import std.typecons : tuple;

    Options options;

    auto defaultGetoptArgs = tuple(
        args,
        "llvm-path", "The path to the LLVM/Clang root directory.", &options.llvmPath,
        // "ncurses-lib-path", "The path to the ncurses library.", &options.ncursesLibPath,
        "statically-link-clang", "Statically link libclang. Defaults to no.", &options.staticallyLinkClang,
        "statically-link-binary", "Completely statically link the binary. Defaults to no.", &options.staticallyLinkBinary
    );

    version (OSX)
        auto getoptArgs = defaultGetoptArgs;
    else
    {
        auto getoptArgs = tuple(
            defaultGetoptArgs.tupleof,
            "statically-link-binary", "Completely statically link the binary. Defaults to no.", &options.staticallyLinkBinary
        );
    }

    auto help = getopt(defaultGetoptArgs.tupleof);
    postProcessArguments(help, options);

    return options;
}

/**
 * Post processes the arguments.
 *
 * This will:
 * $(UL
 *      $(LI Print the help/usage information, if that was requested)
 *      $(LI
 *          Set the `help` field of the `options` struct to `true`, if help was
 *          requested
 *      )
 *      $(LI
 *           Set `staticallyLinkClang` to `true` if `staticallyLinkBinary` is
 *           true
 *      )
 * )
 *
 * Params:
 *  result = the result value from the call to `getopt`
 *  options = the struct containing the parsed arguments
 */
void postProcessArguments(GetoptResult result, ref Options options)
{
    if (options.staticallyLinkBinary)
        options.staticallyLinkClang = true;

    if (!result.helpWanted)
        return;

    options.help = true;

    defaultGetoptPrinter("Usage: ./configure [options]\n\nOptions:",
        result.options);
}

/**
 * Enforces that a given set of libraries exist.
 *
 * Params:
 *  name = a textual representation of the set of libraries to check for.
 *      Will be used in error messages
 *
 *  path = the path to the directory where to look for the libraries
 *  libraries = the actual libraries to look for
 *
 * Throws: Exception if any of the given libraries don't exist
 */
void enforceLibrariesExist(string name, string path,
    const(string)[] libraries ...)
{
    auto errorMessage = format("All required %s libraries could not be " ~
        "found in the path '%s'.\nRequired libraries are:\n%s", name, path,
        libraries.join("\n"));

    alias libraryExists = library => path.buildPath(library).exists;

    enforce(libraries.all!(libraryExists), errorMessage);
}

/**
 * Searches the `PATH` environment variable for the given filename.
 *
 * Params:
 *  filename = the filename to search for in the `PATH`
 *
 * Return: the full path to the given filename if found, otherwise `null`
 */
string searchPath(string filename)
{
    auto path =
        environment.get("PATH", "").
        split(':').
        map!(path => path.buildPath(filename)).
        find!(exists);

    return path.empty ? null : path.front;
}
