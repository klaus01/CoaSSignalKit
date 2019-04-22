#import "SMetaDisposable.h"

#import <libkern/OSAtomic.h>
#import <pthread.h>

@interface SMetaDisposable ()
{
    pthread_mutex_t _lock;
    bool _disposed;
    id<SDisposable> _disposable;
}

@end

@implementation SMetaDisposable

- (id)init {
    if (self = [super init]) {
        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

- (void)setDisposable:(id<SDisposable>)disposable
{
    id<SDisposable> previousDisposable = nil;
    bool dispose = false;
    
    pthread_mutex_lock(&_lock);
    dispose = _disposed;
    if (!dispose)
    {
        previousDisposable = _disposable;
        _disposable = disposable;
    }
    pthread_mutex_unlock(&_lock);
    
    if (previousDisposable != nil)
        [previousDisposable dispose];
    
    if (dispose)
        [disposable dispose];
}

- (void)dispose
{
    id<SDisposable> disposable = nil;
    
    pthread_mutex_lock(&_lock);
    if (!_disposed)
    {
        disposable = _disposable;
        _disposed = true;
    }
    pthread_mutex_unlock(&_lock);
    
    if (disposable != nil)
        [disposable dispose];
}

@end
