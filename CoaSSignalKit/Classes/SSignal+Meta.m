#import "SSignal+Meta.h"

#import "SDisposableSet.h"
#import "SMetaDisposable.h"
#import "SSignal+Mapping.h"
#import "SAtomic.h"
#import "SSignal+Pipe.h"
#import <pthread.h>
#import <libkern/OSAtomic.h>

@interface SSignalQueueState : NSObject <SDisposable>
{
    pthread_mutex_t _lock;
    bool _executingSignal;
    bool _terminated;
    bool _queueMode;
    bool _throttleMode;
}

@property (nonatomic) id<SDisposable> disposable;
@property (nonatomic) SMetaDisposable *currentDisposable;
@property (nonatomic, weak) SSubscriber *subscriber;
@property (nonatomic) NSMutableArray *queuedSignals;

@end

@implementation SSignalQueueState

- (instancetype)initWithSubscriber:(SSubscriber *)subscriber queueMode:(bool)queueMode throttleMode:(bool)throttleMode
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        self.subscriber = subscriber;
        self.currentDisposable = [[SMetaDisposable alloc] init];
        self.queuedSignals = queueMode ? [[NSMutableArray alloc] init] : nil;
        _queueMode = queueMode;
        _throttleMode = throttleMode;
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

- (void)beginWithDisposable:(id<SDisposable>)disposable
{
    _disposable = disposable;
}

- (void)enqueueSignal:(SSignal *)signal
{
    bool startSignal = false;
    pthread_mutex_lock(&_lock);
    if (_queueMode && _executingSignal) {
        if (_throttleMode) {
            [_queuedSignals removeAllObjects];
        }
        [_queuedSignals addObject:signal];
    }
    else
    {
        _executingSignal = true;
        startSignal = true;
    }
    pthread_mutex_unlock(&_lock);
    
    if (startSignal)
    {
        __weak SSignalQueueState *weakSelf = self;
        id<SDisposable> disposable = [signal startWithNext:^(id next)
        {
            [_subscriber putNext:next];
        } error:^(id error)
        {
            [_subscriber putError:error];
        } completed:^
        {
            __strong SSignalQueueState *strongSelf = weakSelf;
            if (strongSelf != nil) {
                [strongSelf headCompleted];
            }
        }];
        
        [_currentDisposable setDisposable:disposable];
    }
}

- (void)headCompleted
{
    while (YES) {
        SAtomic *leftFunction = [[SAtomic alloc] initWithValue:@NO];
        SSignal *nextSignal = nil;
        
        bool terminated = false;
        pthread_mutex_lock(&_lock);
        _executingSignal = false;
        
        if (_queueMode)
        {
            if (_queuedSignals.count != 0)
            {
                nextSignal = _queuedSignals[0];
                [_queuedSignals removeObjectAtIndex:0];
                _executingSignal = true;
            }
            else
                terminated = _terminated;
        }
        else
            terminated = _terminated;
        pthread_mutex_unlock(&_lock);
        
        if (terminated)
            [_subscriber putCompletion];
        else if (nextSignal != nil)
        {
            __weak SSignalQueueState *weakSelf = self;
            id<SDisposable> disposable = [nextSignal startWithNext:^(id next)
                                          {
                                              [_subscriber putNext:next];
                                          } error:^(id error)
                                          {
                                              [_subscriber putError:error];
                                          } completed:^
                                          {
                                              __strong SSignalQueueState *strongSelf = weakSelf;
                                              if (strongSelf != nil && [[leftFunction swap:@YES] boolValue]) {
                                                  [strongSelf headCompleted];
                                              }
                                          }];
            
            [_currentDisposable setDisposable:disposable];
        }
        
        if (![[leftFunction swap:@YES] boolValue]) {
            break;
        }
    }
}

- (void)beginCompletion
{
    bool executingSignal = false;
    pthread_mutex_lock(&_lock);
    executingSignal = _executingSignal;
    _terminated = true;
    pthread_mutex_unlock(&_lock);
    
    if (!executingSignal)
        [_subscriber putCompletion];
}

- (void)dispose
{
    [_currentDisposable dispose];
    [_disposable dispose];
}

@end

@implementation SSignal (Meta)

- (SSignal *)switchToLatest
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SSignalQueueState *state = [[SSignalQueueState alloc] initWithSubscriber:subscriber queueMode:false throttleMode:false];
        
        [state beginWithDisposable:[self startWithNext:^(id next)
        {
            [state enqueueSignal:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [state beginCompletion];
        }]];
        
        return state;
    }];
}

- (SSignal *)mapToSignal:(SSignal *(^)(id))f
{
    return [[self map:f] switchToLatest];
}

- (SSignal *)mapToQueue:(SSignal *(^)(id))f
{
    return [[self map:f] queue];
}

- (SSignal *)mapToThrottled:(SSignal *(^)(id))f {
    return [[self map:f] throttled];
}

- (SSignal *)then:(SSignal *)signal
{
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber)
    {
        SDisposableSet *compositeDisposable = [[SDisposableSet alloc] init];
        
        SMetaDisposable *currentDisposable = [[SMetaDisposable alloc] init];
        [compositeDisposable add:currentDisposable];
        
        [currentDisposable setDisposable:[self startWithNext:^(id next)
        {
            [subscriber putNext:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [compositeDisposable add:[signal startWithNext:^(id next)
            {
                [subscriber putNext:next];
            } error:^(id error)
            {
                [subscriber putError:error];
            } completed:^
            {
                [subscriber putCompletion];
            }]];
        }]];
        
        return compositeDisposable;
    }];
}

- (SSignal *)queue
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable> (SSubscriber *subscriber)
    {
        SSignalQueueState *state = [[SSignalQueueState alloc] initWithSubscriber:subscriber queueMode:true throttleMode:false];
        
        [state beginWithDisposable:[self startWithNext:^(id next)
        {
            [state enqueueSignal:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [state beginCompletion];
        }]];
        
        return state;
    }];
}

- (SSignal *)throttled {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SSignalQueueState *state = [[SSignalQueueState alloc] initWithSubscriber:subscriber queueMode:true throttleMode:true];
        [state beginWithDisposable:[self startWithNext:^(id next)
        {
            [state enqueueSignal:next];
        } error:^(id error)
        {
            [subscriber putError:error];
        } completed:^
        {
            [state beginCompletion];
        }]];

        return state;
    }];
}

+ (SSignal *)defer:(SSignal *(^)())generator
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        return [generator() startWithNext:^(id next)
        {
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

@end

@interface SSignalQueue () {
    SPipe *_pipe;
    id<SDisposable> _disposable;
}

@end

@implementation SSignalQueue

- (instancetype)init {
    self = [super init];
    if (self != nil) {
        _pipe = [[SPipe alloc] init];
        _disposable = [[_pipe.signalProducer() queue] startWithNext:nil];
    }
    return self;
}

- (void)dealloc {
    [_disposable dispose];
}

- (SSignal *)enqueue:(SSignal *)signal {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SPipe *disposePipe = [[SPipe alloc] init];
        
        SSignal *proxy = [[[[signal onNext:^(id next) {
            [subscriber putNext:next];
        }] onError:^(id error) {
            [subscriber putError:error];
        }] onCompletion:^{
            [subscriber putCompletion];
        }] catch:^SSignal *(__unused id error) {
            return [SSignal complete];
        }];
        
        _pipe.sink([proxy takeUntilReplacement:disposePipe.signalProducer()]);
        
        return [[SBlockDisposable alloc] initWithBlock:^{
            disposePipe.sink([SSignal complete]);
        }];
    }];
}

@end
