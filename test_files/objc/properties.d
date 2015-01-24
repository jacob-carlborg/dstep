extern (Objective-C):

class Foo
{
	@property int foo () @selector("foo");
	@property void foo (int) @selector("setFoo:");
	@property int version_ () @selector("version");
	@property void version_ (int) @selector("setVersion:");
}