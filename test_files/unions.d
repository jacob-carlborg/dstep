extern (C):

union Foo
{
    int a;
}

union Bar
{
    int x;
}

extern __gshared Bar b;

extern __gshared Foo c;

union A
{
    union B
    {
        int x;
    }

    B b;
}

union C
{
    union _Anonymous_0
    {
        int x;
        int y;
    }
}

union D
{
    int x;
    int y;
}
