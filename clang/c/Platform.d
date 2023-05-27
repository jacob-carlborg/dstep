/*===-- clang-c/Platform.h - C Index platform decls   -------------*- C -*-===*\
|*                                                                            *|
|* Part of the LLVM Project, under the Apache License v2.0 with LLVM          *|
|* Exceptions.                                                                *|
|* See https://llvm.org/LICENSE.txt for license information.                  *|
|* SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception                    *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header provides platform specific macros (dllimport, deprecated, ...) *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

module clang.c.Platform;

extern (C):

/* Windows DLL import/export. */

