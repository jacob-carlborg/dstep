import core.stdc.time;

extern (Objective-C):

class Foo
{
	@property static Object new_ () [new];
	@property static Class class () [class];
	@property static NSInteger version_ () [version];
	@property static void version_ (NSInteger aVersion) [setVersion:];

	@property Object init () [init];

	static void classMethod () [classMethod];
	static void initialize () [initialize];
	static Object allocWithZone (NSZone* zone) [allocWithZone:];

	void instanceMethod () [instanceMethod];
	IMP methodForSelector (SEL aSelector) [methodForSelector:];
	Object performSelector (SEL aSelector, Object object) [performSelector:withObject:];
}