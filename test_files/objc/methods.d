import core.stdc.time;

extern (Objective-C):

class Foo
{
    @property static ObjcObject new_ () @selector("new");
    @property static Class class () @selector("class");
    @property static NSInteger version_ () @selector("version");
    @property static void version_ (NSInteger aVersion) @selector("setVersion:");

    @property ObjcObject init () @selector("init");

    static void classMethod () @selector("classMethod");
    static void initialize () @selector("initialize");
    static ObjcObject allocWithZone (NSZone* zone) @selector("allocWithZone:");

    void instanceMethod () @selector("instanceMethod");
    IMP methodForSelector (SEL aSelector) @selector("methodForSelector:");
    ObjcObject performSelector (SEL aSelector, ObjcObject object) @selector("performSelector:withObject:");
}