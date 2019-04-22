#import "SMulticastSignalManager.h"

#import "SSignal+Multicast.h"
#import "SSignal+SideEffects.h"
#import "SBag.h"
#import "SMetaDisposable.h"
#import "SBlockDisposable.h"

#import <libkern/OSAtomic.h>
#import <pthread.h>

@interface SMulticastSignalManager ()
{
    pthread_mutex_t _lock;
    NSMutableDictionary *_multicastSignals;
    NSMutableDictionary *_standaloneSignalDisposables;
    NSMutableDictionary *_pipeListeners;
}

@end

@implementation SMulticastSignalManager

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        _multicastSignals = [[NSMutableDictionary alloc] init];
        _standaloneSignalDisposables = [[NSMutableDictionary alloc] init];
        _pipeListeners = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc
{
    NSArray *disposables = nil;
    pthread_mutex_lock(&_lock);
    disposables = [_standaloneSignalDisposables allValues];
    pthread_mutex_unlock(&_lock);
    
    for (id<SDisposable> disposable in disposables)
    {
        [disposable dispose];
    }
    pthread_mutex_destroy(&_lock);
}

- (SSignal *)multicastedSignalForKey:(NSString *)key producer:(SSignal *(^)())producer
{
    if (key == nil)
    {
        if (producer)
            return producer();
        else
            return nil;
    }
    
    SSignal *signal = nil;
    pthread_mutex_lock(&_lock);
    signal = _multicastSignals[key];
    if (signal == nil)
    {
        __weak SMulticastSignalManager *weakSelf = self;
        if (producer)
            signal = producer();
        if (signal != nil)
        {
            signal = [[signal onDispose:^
            {
                __strong SMulticastSignalManager *strongSelf = weakSelf;
                if (strongSelf != nil)
                {
                    pthread_mutex_lock(&strongSelf->_lock);
                    [strongSelf->_multicastSignals removeObjectForKey:key];
                    pthread_mutex_unlock(&strongSelf->_lock);
                }
            }] multicast];
            _multicastSignals[key] = signal;
        }
    }
    pthread_mutex_unlock(&_lock);
    
    return signal;
}

- (void)startStandaloneSignalIfNotRunningForKey:(NSString *)key producer:(SSignal *(^)())producer
{
    if (key == nil)
        return;
    
    bool produce = false;
    pthread_mutex_lock(&_lock);
    if (_standaloneSignalDisposables[key] == nil)
    {
        _standaloneSignalDisposables[key] = [[SMetaDisposable alloc] init];
        produce = true;
    }
    pthread_mutex_unlock(&_lock);
    
    if (produce)
    {
        __weak SMulticastSignalManager *weakSelf = self;
        id<SDisposable> disposable = [producer() startWithNext:nil error:^(__unused id error)
        {
            __strong SMulticastSignalManager *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                pthread_mutex_lock(&strongSelf->_lock);
                [strongSelf->_standaloneSignalDisposables removeObjectForKey:key];
                pthread_mutex_unlock(&strongSelf->_lock);
            }
        } completed:^
        {
            __strong SMulticastSignalManager *strongSelf = weakSelf;
            if (strongSelf != nil)
            {
                pthread_mutex_lock(&strongSelf->_lock);
                [strongSelf->_standaloneSignalDisposables removeObjectForKey:key];
                pthread_mutex_unlock(&strongSelf->_lock);
            }
        }];
        
        pthread_mutex_lock(&_lock);
        [(SMetaDisposable *)_standaloneSignalDisposables[key] setDisposable:disposable];
        pthread_mutex_unlock(&_lock);
    }
}

- (SSignal *)multicastedPipeForKey:(NSString *)key
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        pthread_mutex_lock(&_lock);
        SBag *bag = _pipeListeners[key];
        if (bag == nil)
        {
            bag = [[SBag alloc] init];
            _pipeListeners[key] = bag;
        }
        NSInteger index = [bag addItem:[^(id next)
        {
            [subscriber putNext:next];
        } copy]];
        pthread_mutex_unlock(&_lock);
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            pthread_mutex_lock(&_lock);
            SBag *bag = _pipeListeners[key];
            [bag removeItem:index];
            if ([bag isEmpty]) {
                [_pipeListeners removeObjectForKey:key];
            }
            pthread_mutex_unlock(&_lock);
        }];
    }];
}

- (void)putNext:(id)next toMulticastedPipeForKey:(NSString *)key
{
    pthread_mutex_lock(&_lock);
    NSArray *pipeListeners = [(SBag *)_pipeListeners[key] copyItems];
    pthread_mutex_unlock(&_lock);
    
    for (void (^listener)(id) in pipeListeners)
    {
        listener(next);
    }
}

@end
