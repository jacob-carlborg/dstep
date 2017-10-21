enum Foo
{
    a = 1
};

enum Bar
{
    b,
    c = 2,
    d = 3
} e;

enum Foo f;

struct A
{
    enum B
    {
        g = 1
    } h;
};

struct C
{
    enum
    {
        i = 1,
        j = 2
    } point;
};

typedef enum
{
    k = 1,
    l = 2
} D;
