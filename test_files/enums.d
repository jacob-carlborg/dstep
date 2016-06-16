extern (C):

enum Foo
{
    a = 1
}

enum Bar
{
    b = 0,
    c = 2,
    d = 3
}

extern __gshared Bar e;

extern __gshared Foo f;

struct A
{
    enum B
    {
        g = 1
    }

    B h;
}

struct C
{
    enum _Anonymous_0
    {
        i = 1,
        j = 2
    }

    _Anonymous_0 point;
}

enum _Anonymous_1
{
    k = 1,
    l = 2
}

alias _Anonymous_1 D;
