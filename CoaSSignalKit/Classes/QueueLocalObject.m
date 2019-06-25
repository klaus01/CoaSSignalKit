#import "QueueLocalObject.h"
#import <CoaSSignalKit/SSignalKit.h>

@implementation QueueLocalObject

- (instancetype)initWithQueue:(SQueue *)queue
                     generate:(id(^)(void))generate
{
    if (self = [super init]) {
        self.queue = queue;
        __weak typeof(self) weakSelf = self;
        [self.queue dispatch:^{
            if (generate) {
                id value = generate();
                if (value) {
                    weakSelf.valueRef = value;
                }
            }
        } synchronous:false];
    }
    return self;
}

- (void)dealloc
{
    if (self.valueRef) {
        [self.queue dispatch:^{
            //            self.valueRef = nil;
        } synchronous:false];
    }
}

- (void)with:(void (^)(id))f
{
    __weak typeof(self) weakSelf = self;
    [self.queue dispatch:^{
        if (self.valueRef) {
            if (f) {
                f(weakSelf.valueRef);
            }
        }
    } synchronous:false];
}

- (id)syncWith:(id(^)(id))f
{
    __block id result = nil;
    __weak typeof(self) weakSelf = self;
    [self.queue dispatchSync:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf.valueRef) {
            if (f) {
                result = f(strongSelf.valueRef);
            }
        }
    }];
    return result;
}

- (SSignal *)signalWith:(SDisposableSet *(^)(id, SSubscriber *sbuscriber))f
{
    __weak typeof(self) weakSelf = self;
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber * subscriber) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf && strongSelf.valueRef && f) {
             return f(strongSelf.valueRef, subscriber);
        }else {
            return [[SMetaDisposable alloc] init];
       }
    }] startOn:self.queue];
}


@end

