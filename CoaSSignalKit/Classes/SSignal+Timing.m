#import "SSignal+Timing.h"

#import "SMetaDisposable.h"
#import "SDisposableSet.h"
#import "SBlockDisposable.h"
#import "SActionDisposable.h"

#import "SSignal+Dispatch.h"

#import "STimer.h"

@implementation SSignal (Timing)

- (SSignal *)delay:(NSTimeInterval)seconds onQueue:(SQueue *)queue
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        
        STimer *timer = [[STimer alloc] initWithTimeout:seconds repeat:false completion:^
        {
            [disposable setDisposable:[self startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        } queue:queue];
        
        [timer start];
        
        [disposable setDisposable:[[SBlockDisposable alloc] initWithBlock:^
        {
            [timer invalidate];
        }]];
        
        return disposable;
    }];
}

- (SSignal *)timeout:(NSTimeInterval)seconds onQueue:(SQueue *)queue orSignal:(SSignal *)signal
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];

        STimer *timer = [[STimer alloc] initWithTimeout:seconds repeat:false completion:^
        {
            [disposable setDisposable:[signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        } queue:queue];
        [timer start];
        
        [disposable setDisposable:[self startWithNext:^(id next)
        {
            [timer invalidate];
            [subscriber putNext:next];
        } error:^(id error)
        {
            [timer invalidate];
            [subscriber putError:error];
        } completed:^
        {
            [timer invalidate];
            [subscriber putCompletion];
        }]];
        
        return disposable;
    }];
}

- (SSignal *)wait:(NSTimeInterval)seconds
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        id<SDisposable> disposable = [self startWithNext:^(id next)
        {
            dispatch_semaphore_signal(semaphore);
            [subscriber putNext:next];
        } error:^(id error)
        {
            dispatch_semaphore_signal(semaphore);
            [subscriber putError:error];
        } completed:^
        {
            dispatch_semaphore_signal(semaphore);
            [subscriber putCompletion];
        }];
        
        dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)));
        
        return disposable;
    }];
}

- (SSignal *)suspendAwareDelay:(NSTimeInterval)timeout queue:(SQueue *)queue {
    return [self suspendAwareDelay:timeout granularity:4.0 queue:queue];
}

- (SSignal *)suspendAwareDelay:(NSTimeInterval)timeout granularity:(NSTimeInterval)granularity queue:(SQueue *)queue {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber) {
        SMetaDisposable *disposable = [[SMetaDisposable alloc] init];
        
        [queue async:^{
            NSTimeInterval beginTimestamp = CFAbsoluteTimeGetCurrent();
        
            void(^startFinalTimer)(void) = ^{
                NSTimeInterval finalTimeout = beginTimestamp + timeout - CFAbsoluteTimeGetCurrent();
                STimer *timer = [[STimer alloc] initWithTimeout:MAX(0.0, finalTimeout) repeat:NO completion:^{
                    [disposable setDisposable:[self startWithNext:^(id next) {
                        [subscriber putNext:next];
                    } error:^(id error) {
                        [subscriber putError:error];
                    } completed:^{
                        [subscriber putCompletion];
                    }]];
                } queue:queue];
                
                [disposable setDisposable:[[SActionDisposable alloc] initWithAction:^{
                    [queue async:^{
                        [timer invalidate];
                    }];
                }]];
                
                [timer start];
            };
        
            if (timeout <= granularity * 1.1) {
                startFinalTimer();
            } else {
                void(^invalidateImpl)(void);
                STimer *timer = [[STimer alloc] initWithTimeout:granularity repeat:YES completion:^{
                    NSTimeInterval currentTimestamp = CFAbsoluteTimeGetCurrent();
                    if (beginTimestamp + timeout - granularity * 1.1 <= currentTimestamp) {
                        !invalidateImpl ?: invalidateImpl();
                        startFinalTimer();
                    }
                } queue:queue];
                
                invalidateImpl = ^{
                    [queue async:^{
                        [timer invalidate];
                    }];
                };
                
                [disposable setDisposable:[[SActionDisposable alloc] initWithAction:^{
                    !invalidateImpl ?: invalidateImpl();
                }]];
                
                [timer start];
            }
        }];
        
        return disposable;
    }];
}

@end
