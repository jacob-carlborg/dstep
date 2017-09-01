/*===-- clang-c/CXErrorCode.h - C Index Error Codes  --------------*- C -*-===*\
|*                                                                            *|
|*                     The LLVM Compiler Infrastructure                       *|
|*                                                                            *|
|* This file is distributed under the University of Illinois Open Source      *|
|* License. See LICENSE.TXT for details.                                      *|
|*                                                                            *|
|*===----------------------------------------------------------------------===*|
|*                                                                            *|
|* This header provides the CXErrorCode enumerators.                          *|
|*                                                                            *|
\*===----------------------------------------------------------------------===*/

module clang.c.CXErrorCode;

extern (C):

/**
 * \brief Error codes returned by libclang routines.
 *
 * Zero (\c CXError_Success) is the only error code indicating success.  Other
 * error codes, including not yet assigned non-zero values, indicate errors.
 */
enum CXErrorCode
{
    /**
     * \brief No error.
     */
    success = 0,

    /**
     * \brief A generic error code, no further details are available.
     *
     * Errors of this kind can get their own specific error codes in future
     * libclang versions.
     */
    failure = 1,

    /**
     * \brief libclang crashed while performing the requested operation.
     */
    crashed = 2,

    /**
     * \brief The function detected that the arguments violate the function
     * contract.
     */
    invalidArguments = 3,

    /**
     * \brief An AST deserialization error has occurred.
     */
    astReadError = 4
}
