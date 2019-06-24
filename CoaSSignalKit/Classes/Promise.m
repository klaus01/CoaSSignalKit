

#import "Promise.h"
#import <pthread.h>

@interface Promise <__covariant T, NoError: NSError *>()

@property (nonatomic) SSignal *initializeOnFirstAccess;
@property (nonatomic) T value;
@property (nonatomic) SMetaDisposable *disposable;
@property (nonatomic) SBag *subscribers;
@property (nonatomic) void(^onDeinit)(void);
@property (nonatomic) pthread_mutex_t lock;

@end

@implementation Promise

- (SMetaDisposable *)disposable {
    if (!_disposable) {
        _disposable = [SMetaDisposable new];
    }
    return _disposable;
}

- (SBag *)subscribers {
    if (!_subscribers) {
        _subscribers = [SBag new];
    }
    return _subscribers;
}

- (id)initWithInitializeOnFirstAccess:(SSignal *)signal {
    if (self = [super init]) {
        self.initializeOnFirstAccess = signal;
        pthread_mutex_init(&_lock, nil);
    }
    return self;
}

- (id)initWithValue:(id)value {
    if (self = [super init]) {
        self.value = value;
        pthread_mutex_init(&_lock, nil);
    }
    return self;
}

- (instancetype)init {
    if (self = [super init]) {
        pthread_mutex_init(&_lock, nil);
    }
    return self;
}

- (void)dealloc {
    !self.onDeinit ?: self.onDeinit();
    pthread_mutex_destroy(&_lock);
    [_disposable dispose];
}

- (void)set:(SSignal *)signal {
    pthread_mutex_lock(&_lock);
    self.value = nil;
    pthread_mutex_unlock(&_lock);
    __weak typeof(self) weakSelf = self;
    [self.disposable setDisposable:[signal startWithNext:^(id next) {
        __strong typeof (weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            pthread_mutex_lock(&strongSelf->_lock);
            strongSelf.value = next;
            NSArray *subscribers = [strongSelf.subscribers copyItems];
            pthread_mutex_unlock(&strongSelf->_lock);
            
            for (void(^subsriber)(id next) in subscribers) {
                subsriber(next);
            }
        }
    }]];
}

- (SSignal *)get {
    __weak typeof(self) weakSelf = self;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber * subscriber) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        pthread_mutex_lock(&strongSelf->_lock);
        SSignal *initializeOnFirstAccessNow;
        SSignal *initializeOnFirstAccess;
        if ((initializeOnFirstAccess = strongSelf.initializeOnFirstAccess)) {
            initializeOnFirstAccessNow = initializeOnFirstAccess;
            strongSelf.initializeOnFirstAccess = nil;
        }
        id currentValue = strongSelf.value;
        NSInteger index = [strongSelf.subscribers addItem:^(id next) {
            [subscriber putNext:next];
        }];
        pthread_mutex_unlock(&strongSelf->_lock);
        if (currentValue) {
            [subscriber putNext:currentValue];
        }
        if (initializeOnFirstAccessNow) {
            [strongSelf set:initializeOnFirstAccessNow];
        }
        return [[SBlockDisposable alloc] initWithBlock:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                pthread_mutex_lock(&strongSelf->_lock);
                [strongSelf.subscribers removeItem:index];
                pthread_mutex_unlock(&strongSelf->_lock);
            }
        }];
    }];
}

@end

@interface ValuePromise<__covariant T : id> ()

@property (nonatomic) T value;
@property (nonatomic) pthread_mutex_t lock;
@property (nonatomic) SBag *subscribers;
@property (nonatomic) BOOL ignoreRepeated;

@end

@implementation ValuePromise

- (SBag *)subscribers {
    if (!_subscribers) {
        _subscribers = [[SBag alloc] init];
    }
    return _subscribers;
}

- (id)initWithValue:(id)value ignoreRepeated:(BOOL)ignoreRepeated {
    if (self = [super init]) {
        self.value = value;
        self.ignoreRepeated = ignoreRepeated;
        pthread_mutex_init(&self->_lock, nil);
    }
    return self;
}

- (id)initWithIgnoreRepeated:(BOOL)ignoreReapted {
    if (self = [super init]) {
        self.ignoreRepeated = ignoreReapted;
        pthread_mutex_init(&self->_lock, nil);
    }
    return self;
}

- (instancetype)init {
    if (self = [super init]) {
        pthread_mutex_init(&self->_lock, nil);
    }
    return self;
}

- (void)set:(id)value {
    pthread_mutex_lock(&self->_lock);
    NSArray *subscribers;
    BOOL isEqualValue = self.value == value || (value && [self.value isEqual:value]);
    if (!self.ignoreRepeated || !isEqualValue) {
        self.value = value;
        subscribers = [self.subscribers copyItems];
    } else {
        subscribers = @[];
    }
    pthread_mutex_unlock(&self->_lock);
    
    for (void(^subscriber)(id) in subscribers) {
        subscriber(value);
    }
}

- (SSignal *)get {
    __weak typeof(self) weakSelf = self;
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        pthread_mutex_lock(&strongSelf->_lock);
        id currentValue = strongSelf.value;
        NSInteger index = [strongSelf.subscribers addItem:^(id next) {
            [subscriber putNext:next];
        }];
        pthread_mutex_unlock(&strongSelf->_lock);
    
        if (currentValue) {
            [subscriber putNext:currentValue];
        }
        
        return [[SBlockDisposable alloc] initWithBlock:^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                pthread_mutex_lock(&strongSelf->_lock);
                [strongSelf.subscribers removeItem:index];
                pthread_mutex_unlock(&strongSelf->_lock);
            }
        }];
    }];
}

- (void)dealloc {
    pthread_mutex_destroy(&self->_lock);
}

@end
