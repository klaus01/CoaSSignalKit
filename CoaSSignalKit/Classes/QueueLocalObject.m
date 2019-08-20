#import "QueueLocalObject.h"
#import <CoaSSignalKit/SSignalKit.h>

@interface QueueLocalObject()

@property (nonatomic, unsafe_unretained) id valueRef;

@end

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
                    weakSelf.valueRef = (__bridge id)(CFRetain((__bridge CFTypeRef)value));
                }
            }
        } synchronous:false];
    }
    return self;
}

- (void)dealloc {
    id valueRef = self.valueRef;
    [self.queue dispatch:^{
        CFRelease((__bridge CFTypeRef)(valueRef));
    } synchronous:false];
}

- (void)with:(void (^)(id))f {
    __weak typeof(self) weakSelf = self;
    [self.queue dispatch:^{
        id value;
        if ((value = self.valueRef)) {
            f(value);
        }
    } synchronous:false];
}

- (id)syncWith:(id(^)(id))f {
    __block id result = nil;
    __weak typeof(self) weakSelf = self;
    [self.queue dispatchSync:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id valueRef;
        if ((valueRef = strongSelf.valueRef)) {
            result = f(valueRef);
        }
    }];
    return result;
}

- (SSignal *)signalWith:(SDisposableSet *(^)(id, SSubscriber *sbuscriber))f {
    __weak typeof(self) weakSelf = self;
    return [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber * subscriber) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        id valueRef;
        if (strongSelf && (valueRef = strongSelf.valueRef) && f) {
             return f(valueRef, subscriber);
        }else {
            return [[SMetaDisposable alloc] init];
       }
    }] runOn:self.queue];
}


@end

