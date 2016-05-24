extern (C):

struct Foo
{
    int a;
}

struct Bar
{
    int x;
}

extern __gshared Bar b;

extern __gshared Foo c;

struct A
{
    struct B
    {
        int x;
    }

    B b;
}

struct C
{
    struct
    {
        int x;
        int y;
    }
}

struct _Anonymous_0
{
    int x;
    int y;
}

alias _Anonymous_0 D;

struct E
{
}

struct Nested
{
    C field;
}

struct F;