#import "SSignal+Mapping.h"

#import "SAtomic.h"

@implementation DistinctUntilChangedContext

@end

@interface SSignalIgnoreRepeatedState: NSObject

@property (nonatomic, strong) id value;
@property (nonatomic) bool hasValue;

@end

@implementation SSignalIgnoreRepeatedState

@end

@implementation SSignal (Mapping)

- (SSignal *)map:(id (^)(id))f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            [subscriber putNext:f(next)];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (SSignal *)filter:(bool (^)(id))f
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        return [self startWithNext:^(id next)
        {
            if (f(next))
                [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (SSignal *)ignoreRepeated {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SAtomic *state = [[SAtomic alloc] initWithValue:[[SSignalIgnoreRepeatedState alloc] init]];
        
        return [self startWithNext:^(id next) {
            bool shouldPassthrough = [[state with:^id(SSignalIgnoreRepeatedState *state) {
                if (!state.hasValue) {
                    state.hasValue = true;
                    state.value = next;
                    return @true;
                } else if ((state.value == nil && next == nil) || [(id<NSObject>)state.value isEqual:next]) {
                    return @false;
                }
                state.value = next;
                return @true;
            }] boolValue];
            
            if (shouldPassthrough) {
                [subscriber putNext:next];
            }
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [subscriber putCompletion];
        }];
    }];
}

- (SSignal *)distinctUntilChanged
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber * subscriber) {
        
        DistinctUntilChangedContext *changedContext = [[DistinctUntilChangedContext alloc] init];
        
        SAtomic *context = [[SAtomic alloc] initWithValue:changedContext];
        
        return [self startWithNext:^(id next) {
            NSNumber *passValue = [context with:^id(DistinctUntilChangedContext *context) {
                if ((context.value && context.value == next) || [(id<NSObject>)context.value isEqual:next]) {
                    return @(NO);
                }else {
                    context.value = next;
                    return @(YES);
                }
            }];
            BOOL pass = [passValue boolValue];
            if (pass) {
                [subscriber putNext:next];
            }
            
        }error:^(id error) {
            [subscriber putError:error];
        } completed:^{
            [subscriber putCompletion];
        }];
        
    }];
}

- (SSignal *(^)(SSignal *))distinctUntilChangedisEqual:(BOOL(^)(id, id))isEqual
{
    return ^ SSignal *(SSignal *signal) {
        return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
            
            DistinctUntilChangedContext *changedContext = [[DistinctUntilChangedContext alloc] init];
            
            SAtomic *context = [[SAtomic alloc] initWithValue:changedContext];
            
            return [signal startWithNext:^(id next) {
                BOOL pass = [context with:^id(DistinctUntilChangedContext *context) {
                    BOOL equal = NO;
                    if (isEqual) {
                        equal = isEqual(context.value, next);
                    }
                    if (context.value && equal) {
                        return @(NO);
                    }else {
                        context.value = next;
                        return @(YES);
                    }
                }];
                
                if (pass) {
                    [subscriber putNext:next];
                }
                
            }error:^(id error) {
                [subscriber putError:error];
            } completed:^{
                [subscriber putCompletion];
            }];
            
        }];
    };
}


@end
