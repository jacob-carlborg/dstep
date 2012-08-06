import core.stdc.time;

extern (Objective-C):

class Foo
{
	@property Object new_ () [new];
	@property Class class_ () [class];
	@property Object init () [init];
	@property NSInteger version_ () [version];
	@property void version_ (NSInteger aVersion) [setVersion:];

	static void classMethod () [classMethod];
	static void initialize () [initialize];
	static Object allocWithZone (NSZone* zone) [allocWithZone:];

	void instanceMethod () [instanceMethod];
	IMP methodForSelector (SEL aSelector) [methodForSelector:];
	Object performSelector (SEL aSelector, Object object) [performSelector:withObject:];
}