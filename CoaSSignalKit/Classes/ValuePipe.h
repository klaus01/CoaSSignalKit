
#import <Foundation/Foundation.h>
#import "SSignal.h"

@interface ValuePipe<__covariant T> : NSObject

@property (nonatomic, readonly) SSignal *signal;

- (void)putNext:(T)next;

@end
