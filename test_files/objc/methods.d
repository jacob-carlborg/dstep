class Foo
{
	static void classMethod () [classMethod];
	static void initialize () [initialize];
	static Object allocWithZone (NSZone* zone) [allocWithZone:];

	void instanceMethod () [instanceMethod];
	Object init () [init];
	IMP methodForSelector (SEL aSelector) [methodForSelector:];
	Object performSelector (SEL aSelector, Object object) [performSelector:withObject:];
}