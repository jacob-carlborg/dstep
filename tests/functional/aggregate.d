extern (C):

int b (int out_);

struct Foo
{
    int a;
}

float foo (Foo x);
float bar (Foo x);

extern __gshared int a;

struct Bar
{
    int x;
    int y;
}

extern __gshared const(char)* q;

extern __gshared int function (int a, int b) e;
