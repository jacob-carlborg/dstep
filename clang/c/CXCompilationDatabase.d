/*===-- clang-c/CXCompilationDatabase.h - Compilation database  ---*- C -*-===*\
|*                                                                            *|
|*                     The LLVM Compiler Infrastructure                       *|
|*                                                                            *|
|* This file is distributed under the University of Illinois Open Source      *|
|* License. See LICENSE.TXT for details.                                      *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header provides a public inferface to use CompilationDatabase without *|
|* the full Clang C++ API.                                                    *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

module clang.c.CXCompilationDatabase;

public import clang.c.CXString;

extern (C):

/** \defgroup COMPILATIONDB CompilationDatabase functions
 * \ingroup CINDEX
 *
 * @{
 */

/**
 * A compilation database holds all information used to compile files in a
 * project. For each file in the database, it can be queried for the working
 * directory or the command line used for the compiler invocation.
 *
 * Must be freed by \c clang_CompilationDatabase_dispose
 */
alias CXCompilationDatabase = void*;

/**
 * \brief Contains the results of a search in the compilation database
 *
 * When searching for the compile command for a file, the compilation db can
 * return several commands, as the file may have been compiled with
 * different options in different places of the project. This choice of compile
 * commands is wrapped in this opaque data structure. It must be freed by
 * \c clang_CompileCommands_dispose.
 */
alias CXCompileCommands = void*;

/**
 * \brief Represents the command line invocation to compile a specific file.
 */
alias CXCompileCommand = void*;

/**
 * \brief Error codes for Compilation Database
 */
enum CXCompilationDatabase_Error
{
    /*
     * \brief No error occurred
     */
    CXCompilationDatabase_NoError = 0,

    /*
     * \brief Database can not be loaded
     */
    CXCompilationDatabase_CanNotLoadDatabase = 1
}

/**
 * \brief Creates a compilation database from the database found in directory
 * buildDir. For example, CMake can output a compile_commands.json which can
 * be used to build the database.
 *
 * It must be freed by \c clang_CompilationDatabase_dispose.
 */
CXCompilationDatabase clang_CompilationDatabase_fromDirectory(
    const(char)* BuildDir,
    CXCompilationDatabase_Error* ErrorCode);

/**
 * \brief Free the given compilation database
 */
void clang_CompilationDatabase_dispose(CXCompilationDatabase);

/**
 * \brief Find the compile commands used for a file. The compile commands
 * must be freed by \c clang_CompileCommands_dispose.
 */
CXCompileCommands clang_CompilationDatabase_getCompileCommands(
    CXCompilationDatabase,
    const(char)* CompleteFileName);

/**
 * \brief Get all the compile commands in the given compilation database.
 */
CXCompileCommands clang_CompilationDatabase_getAllCompileCommands(
    CXCompilationDatabase);

/**
 * \brief Free the given CompileCommands
 */
void clang_CompileCommands_dispose(CXCompileCommands);

/**
 * \brief Get the number of CompileCommand we have for a file
 */
uint clang_CompileCommands_getSize(CXCompileCommands);

/**
 * \brief Get the I'th CompileCommand for a file
 *
 * Note : 0 <= i < clang_CompileCommands_getSize(CXCompileCommands)
 */
CXCompileCommand clang_CompileCommands_getCommand(CXCompileCommands, uint I);

/**
 * \brief Get the working directory where the CompileCommand was executed from
 */
CXString clang_CompileCommand_getDirectory(CXCompileCommand);

/**
 * \brief Get the filename associated with the CompileCommand.
 */
CXString clang_CompileCommand_getFilename(CXCompileCommand);

/**
 * \brief Get the number of arguments in the compiler invocation.
 *
 */
uint clang_CompileCommand_getNumArgs(CXCompileCommand);

/**
 * \brief Get the I'th argument value in the compiler invocations
 *
 * Invariant :
 *  - argument 0 is the compiler executable
 */
CXString clang_CompileCommand_getArg(CXCompileCommand, uint I);

/**
 * \brief Get the number of source mappings for the compiler invocation.
 */
uint clang_CompileCommand_getNumMappedSources(CXCompileCommand);

/**
 * \brief Get the I'th mapped source path for the compiler invocation.
 */
CXString clang_CompileCommand_getMappedSourcePath(CXCompileCommand, uint I);

/**
 * \brief Get the I'th mapped source content for the compiler invocation.
 */
CXString clang_CompileCommand_getMappedSourceContent(CXCompileCommand, uint I);

/**
 * @}
 */

