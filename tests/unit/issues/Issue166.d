import Common;

@("issue #166 - translate record with name from macro")
unittest
{
    assertTranslates(
    q"C

#define __FSID_T_TYPE struct { int __val[2]; }
typedef  __FSID_T_TYPE __fsid_t;
typedef __fsid_t fsid_t;

C",
    q"D
extern (C):

struct __fsid_t
{
    int[2] __val;
}

alias fsid_t = __fsid_t;

D");

}


@("issue #166 - translate record with name from macro in a literal macro")
unittest
{
    assertTranslates(
        q"C
#define FOO 2
#define __FSID_T_TYPE struct { int __val[FOO]; }
typedef  __FSID_T_TYPE __fsid_t;
typedef __fsid_t fsid_t;
C",
        q"D
extern (C):

enum FOO = 2;

struct __fsid_t
{
    int[FOO] __val;
}

alias fsid_t = __fsid_t;

D");

}


@("issue #166 - translate record with name from macro in a macro in a macro")
unittest
{
    assertTranslates(
        q"C
#define FOO 2
#define BAR FOO
#define __FSID_T_TYPE struct { int __val[BAR]; }
typedef  __FSID_T_TYPE __fsid_t;
typedef __fsid_t fsid_t;
C",
        q"D
extern (C):

enum FOO = 2;
enum BAR = FOO;

struct __fsid_t
{
    int[BAR] __val;
}

alias fsid_t = __fsid_t;

D");

}
