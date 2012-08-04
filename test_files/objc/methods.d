extern (Objective-C):

class Foo
{
	@property Object init ();

	static void classMethod () [classMethod];
	static void initialize () [initialize];
	static Object allocWithZone (NSZone* zone) [allocWithZone:];

	void instanceMethod () [instanceMethod];
	IMP methodForSelector (SEL aSelector) [methodForSelector:];
	Object performSelector (SEL aSelector, Object object) [performSelector:withObject:];
}