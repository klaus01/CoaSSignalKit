#import <Foundation/Foundation.h>

@interface SQueue : NSObject

+ (SQueue *)mainQueue;
+ (SQueue *)concurrentDefaultQueue;
+ (SQueue *)concurrentBackgroundQueue;

+ (SQueue *)wrapConcurrentNativeQueue:(dispatch_queue_t)nativeQueue;
- (SQueue *)initWithName:(NSString *)name qos:(dispatch_qos_class_t)qos;

- (void)dispatch:(dispatch_block_t)block;
- (void)dispatchSync:(dispatch_block_t)block;
- (void)dispatch:(dispatch_block_t)block synchronous:(bool)synchronous;
- (void)async:(dispatch_block_t)f;
- (void)sync:(dispatch_block_t)f;

- (void)justDispatch:(dispatch_block_t)block;
- (void)justDispatchWithQos:(dispatch_qos_class_t)qos f:(dispatch_block_t)f;
- (void)after:(double)delay f:(dispatch_block_t)f;

- (dispatch_queue_t)_dispatch_queue;

- (bool)isCurrentQueue;

@end
