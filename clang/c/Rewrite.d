/*===-- clang-c/Rewrite.h - C CXRewriter   --------------------------*- C -*-===*\
|*                                                                            *|
|* Part of the LLVM Project, under the Apache License v2.0 with LLVM          *|
|* Exceptions.                                                                *|
|* See https://llvm.org/LICENSE.txt for license information.                  *|
|* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*/

module clang.c.Rewrite;

public import clang.c.Index;

extern (C):

alias CXRewriter = void*;

/**
 * Create CXRewriter.
 */
CXRewriter clang_CXRewriter_create(CXTranslationUnit TU);

/**
 * Insert the specified string at the specified location in the original buffer.
 */
void clang_CXRewriter_insertTextBefore(
    CXRewriter Rew,
    CXSourceLocation Loc,
    const(char)* Insert);

/**
 * Replace the specified range of characters in the input with the specified
 * replacement.
 */
void clang_CXRewriter_replaceText(
    CXRewriter Rew,
    CXSourceRange ToBeReplaced,
    const(char)* Replacement);

/**
 * Remove the specified range.
 */
void clang_CXRewriter_removeText(CXRewriter Rew, CXSourceRange ToBeRemoved);

/**
 * Save all changed files to disk.
 * Returns 1 if any files were not saved successfully, returns 0 otherwise.
 */
int clang_CXRewriter_overwriteChangedFiles(CXRewriter Rew);

/**
 * Write out rewritten version of the main file to stdout.
 */
void clang_CXRewriter_writeMainFileToStdOut(CXRewriter Rew);

/**
 * Free the given CXRewriter.
 */
void clang_CXRewriter_dispose(CXRewriter Rew);

