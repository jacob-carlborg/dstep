#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSZone.h>

@interface Foo

+ (void) classMethod;
- (void) instanceMethod;

+ (void)initialize;
+ (id)new;
+ (Class)class;
- (id)init;

+ (id)allocWithZone:(NSZone *)zone;
- (IMP)methodForSelector:(SEL)aSelector;

+ (NSInteger)version;
+ (void)setVersion:(NSInteger)aVersion;

- (id)performSelector:(SEL)aSelector withObject:(id)object;

@end
