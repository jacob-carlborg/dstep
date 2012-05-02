#import <Foundation/NSObjCRuntime.h>
#import <Foundation/NSZone.h>

@interface Foo

+ (void) classMethod;
- (void) instanceMethod;

+ (void)initialize;
- (id)init;

+ (id)allocWithZone:(NSZone *)zone;
- (IMP)methodForSelector:(SEL)aSelector;

- (id)performSelector:(SEL)aSelector withObject:(id)object;

@end