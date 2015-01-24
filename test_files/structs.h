struct Foo
{
    int a;
};

struct Bar
{
    int x;
} b;

struct Foo c;

struct A
{
    struct B
    {
        int x;
    } b;
};

struct C
{
    struct
    {
        int x;
        int y;
    } point;
};

typedef struct
{
    int x;
    int y;
} D;

struct E;

struct E
{
};

struct F;
