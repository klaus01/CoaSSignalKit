#import "SDisposableSet.h"

#import "SSignal.h"

#import <libkern/OSAtomic.h>
#import <pthread.h>

@interface SDisposableSet ()
{
    pthread_mutex_t _lock;
    bool _disposed;
    id<SDisposable> _singleDisposable;
    NSArray *_multipleDisposables;
}

@end

@implementation SDisposableSet

- (id)init {
    if (self = [super init]) {
        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

- (void)add:(id<SDisposable>)disposable
{
    if (disposable == nil)
        return;
    
    bool dispose = false;
    
    pthread_mutex_lock(&_lock);
    dispose = _disposed;
    if (!dispose)
    {
        if (_multipleDisposables != nil)
        {
            NSMutableArray *multipleDisposables = [[NSMutableArray alloc] initWithArray:_multipleDisposables];
            [multipleDisposables addObject:disposable];
            _multipleDisposables = multipleDisposables;
        }
        else if (_singleDisposable != nil)
        {
            NSMutableArray *multipleDisposables = [[NSMutableArray alloc] initWithObjects:_singleDisposable, disposable, nil];
            _multipleDisposables = multipleDisposables;
            _singleDisposable = nil;
        }
        else
        {
            _singleDisposable = disposable;
        }
    }
    pthread_mutex_unlock(&_lock);
    
    if (dispose)
        [disposable dispose];
}

- (void)remove:(id<SDisposable>)disposable {
    pthread_mutex_lock(&_lock);
    if (_multipleDisposables != nil)
    {
        NSMutableArray *multipleDisposables = [[NSMutableArray alloc] initWithArray:_multipleDisposables];
        [multipleDisposables removeObject:disposable];
        _multipleDisposables = multipleDisposables;
    }
    else if (_singleDisposable == disposable)
    {
        _singleDisposable = nil;
    }
    pthread_mutex_unlock(&_lock);
}

- (void)dispose
{
    id<SDisposable> singleDisposable = nil;
    NSArray *multipleDisposables = nil;
    
    pthread_mutex_lock(&_lock);
    if (!_disposed)
    {
        _disposed = true;
        singleDisposable = _singleDisposable;
        multipleDisposables = _multipleDisposables;
        _singleDisposable = nil;
        _multipleDisposables = nil;
    }
    pthread_mutex_unlock(&_lock);
    
    if (singleDisposable != nil)
        [singleDisposable dispose];
    if (multipleDisposables != nil)
    {
        for (id<SDisposable> disposable in multipleDisposables)
        {
            [disposable dispose];
        }
    }
}

@end
