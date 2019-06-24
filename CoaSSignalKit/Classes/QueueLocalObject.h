#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class SDisposableSet, SSignal, SQueue, SSubscriber;
@interface QueueLocalObject<__covariant T> : NSObject
@property (nonatomic, strong) SQueue *queue;
@property (nullable, nonatomic, strong) T valeueRef;

- (instancetype)initWithQueue:(SQueue *)queue
                     generate:(T(^)(void))generate;

- (void)with:(void (^)(T))f;

- (id)syncWith:(id(^)(T))f;

- (SSignal *)signalWith:(SDisposableSet *(^)(T, SSubscriber *sbuscriber))f;

@end

NS_ASSUME_NONNULL_END
