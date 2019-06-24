
#import "ValuePipe.h"
#import "SAtomic.h"
#import "SBag.h"
#import "SBlockDisposable.h"

@interface ValuePipe()

@property (nonatomic) SAtomic *subscribers;

@end

@implementation ValuePipe

- (SAtomic *)subscribers {
    if (!_subscribers) {
        _subscribers = [[SAtomic alloc] initWithValue:[SBag new]];
    }
    return _subscribers;
}

- (SSignal *)signal {
    __weak typeof(self) weakSelf = self;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            NSNumber *index = [strongSelf.subscribers with:^NSNumber *(SBag *value) {
                return @([value addItem:^(id next){
                    [subscriber putNext:next];
                }]);
            }];
            __weak typeof(strongSelf) wStrongSelf = strongSelf;
            return [[SBlockDisposable alloc] initWithBlock:^{
                __strong typeof(wStrongSelf) sStrongSelf = wStrongSelf;
                [sStrongSelf.subscribers with:^id(SBag *value) {
                    [value removeItem:index.integerValue];
                    return nil;
                }];
            }];
        } else {
            return nil;
        }
    }];
}

- (void)putNext:(id)next {
    NSArray *items = [self.subscribers with:^NSArray *(SBag *value) {
        return [value copyItems];
    }];
    for (void(^f)(id) in items) {
        f(next);
    }
}

@end
