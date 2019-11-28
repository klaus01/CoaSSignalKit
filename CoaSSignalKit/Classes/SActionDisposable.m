#import "SActionDisposable.h"
#import <pthread.h>

@interface _SEmptyDisposable : NSObject<SDisposable>
@end

@implementation _SEmptyDisposable
- (void)dispose {}
@end

id<SDisposable> SEmptyDisposable() {
    static dispatch_once_t onceToken;
    __block id<SDisposable> _emptyDisposable = nil;
    dispatch_once(&onceToken, ^{
        _emptyDisposable = [[_SEmptyDisposable alloc] init];
    });
    return _emptyDisposable;
}

@interface SActionDisposable () {
    pthread_mutex_t _lock;
}
@property (nonatomic, copy) void(^action)(void);
@end

@implementation SActionDisposable

- (instancetype)initWithAction:(void (^)(void))action {
    if (self = [super init]) {
        self.action = action;
        pthread_mutex_init(&_lock, nil);
    }
    return self;
}

- (void)dealloc {
    void(^freeaction)(void);
    pthread_mutex_lock(&_lock);
    freeaction = self.action;
    pthread_mutex_unlock(&_lock);
    
    if (freeaction) {
        freeaction();
    }
    pthread_mutex_destroy(&_lock);
}

- (void)dispose {
    void(^disposeAction)(void);
    pthread_mutex_lock(&_lock);
    disposeAction = self.action;
    self.action = nil;
    pthread_mutex_unlock(&_lock);
    if (disposeAction) {
        disposeAction();
    }
}

@end
