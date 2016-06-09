extern (Objective-C):

class Foo
{
    static void classMethod () @selector("classMethod");
    void instanceMethod () @selector("instanceMethod");
    static void initialize () @selector("initialize");
    @property static ObjcObject new_ () @selector("new");
    @property static Class class () @selector("class");
    @property ObjcObject init () @selector("init");
    static ObjcObject allocWithZone (NSZone* zone) @selector("allocWithZone:");
    IMP methodForSelector (SEL aSelector) @selector("methodForSelector:");
    @property static NSInteger version_ () @selector("version");
    @property static void version_ (NSInteger aVersion) @selector("setVersion:");
    ObjcObject performSelector (SEL aSelector, ObjcObject object) @selector("performSelector:withObject:");
}