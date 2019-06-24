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
                    weakSelf.valeueRef = value;
                }
            }
        } synchronous:false];
    }
    return self;
}

- (void)dealloc
{
    if (self.valeueRef) {
        [self.queue dispatch:^{
            //            self.valeueRef = nil;
        } synchronous:false];
    }
}

- (void)with:(void (^)(id))f
{
    __weak typeof(self) weakSelf = self;
    [self.queue dispatch:^{
        if (self.valeueRef) {
            if (f) {
                f(weakSelf.valeueRef);
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
        if (strongSelf.valeueRef) {
            if (f) {
                result = f(strongSelf.valeueRef);
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
        if (strongSelf && strongSelf.valeueRef) {
            if (f) {
                return f(strongSelf.valeueRef, subscriber);
            }else {
                return nil;
            }
        }else {
            return [[SMetaDisposable alloc] init];
        }
    }] startOn:self.queue];
}


@end

