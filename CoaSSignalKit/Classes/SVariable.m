#import "SVariable.h"

#import <libkern/OSAtomic.h>
#import <pthread.h>
#import "SSignal.h"
#import "SBag.h"
#import "SBlockDisposable.h"
#import "SMetaDisposable.h"

@interface SVariable ()
{
    pthread_mutex_t _lock;
    id _value;
    bool _hasValue;
    SBag *_subscribers;
    SMetaDisposable *_disposable;
}

@end

@implementation SVariable

- (instancetype)init
{
    self = [super init];
    if (self != nil)
    {
        pthread_mutex_init(&_lock, NULL);
        _subscribers = [[SBag alloc] init];
        _disposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc
{
    pthread_mutex_destroy(&_lock);
    [_disposable dispose];
}

- (SSignal *)signal
{
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber)
    {
        pthread_mutex_lock(&self->_lock);
        id currentValue = _value;
        bool hasValue = _hasValue;
        NSInteger index = [self->_subscribers addItem:[^(id value)
        {
            [subscriber putNext:value];
        } copy]];
        pthread_mutex_unlock(&self->_lock);
        
        if (hasValue)
        {
            [subscriber putNext:currentValue];
        }
        
        return [[SBlockDisposable alloc] initWithBlock:^
        {
            pthread_mutex_lock(&self->_lock);
            [self->_subscribers removeItem:index];
            pthread_mutex_unlock(&self->_lock);
        }];
    }];
}

- (void)set:(SSignal *)signal
{
    pthread_mutex_lock(&_lock);
    _hasValue = false;
    pthread_mutex_unlock(&_lock);
    
    __weak SVariable *weakSelf = self;
    [_disposable setDisposable:[signal startWithNext:^(id next)
    {
        __strong SVariable *strongSelf = weakSelf;
        if (strongSelf != nil)
        {
            NSArray *subscribers = nil;
            pthread_mutex_lock(&strongSelf->_lock);
            strongSelf->_value = next;
            strongSelf->_hasValue = true;
            subscribers = [strongSelf->_subscribers copyItems];
            pthread_mutex_unlock(&strongSelf->_lock);
            
            for (void (^subscriber)(id) in subscribers)
            {
                subscriber(next);
            }
        }
    }]];
}

@end
