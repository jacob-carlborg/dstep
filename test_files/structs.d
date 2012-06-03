extern __gshared Bar b;
extern __gshared Foo c;

struct Foo
{
	int a;
}

struct Bar
{
	int x;
}

struct A
{
	struct B
	{
		int x;
	}
	B b;
}