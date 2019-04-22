#import "SSubscriber.h"
#import <libkern/OSAtomic.h>
#import <pthread.h>

@interface SSubscriberBlocks : NSObject {
    @public
    void (^_next)(id);
    void (^_error)(id);
    void (^_completed)();
}

@end

@implementation SSubscriberBlocks

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed {
    self = [super init];
    if (self != nil) {
        _next = [next copy];
        _error = [error copy];
        _completed = [completed copy];
    }
    return self;
}

@end

@interface SSubscriber ()
{
    @protected
    pthread_mutex_t _lock;
    bool _terminated;
    id<SDisposable> _disposable;
    SSubscriberBlocks *_blocks;
}

@end

@implementation SSubscriber

- (id<SDisposable>)disposable {
    return _disposable;
}

- (BOOL)terminated {
    return _terminated;
}

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed
{
    self = [super init];
    if (self != nil)
    {
        _blocks = [[SSubscriberBlocks alloc] initWithNext:next error:error completed:completed];
        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

- (void)_assignDisposable:(id<SDisposable>)disposable
{
    bool dispose = false;
    pthread_mutex_lock(&_lock);
    if (_terminated) {
        dispose = true;
    } else {
        _disposable = disposable;
    }
    pthread_mutex_unlock(&_lock);
    if (dispose) {
        [disposable dispose];
    }
}

- (void)_markTerminatedWithoutDisposal
{
    pthread_mutex_lock(&_lock);
    SSubscriberBlocks *blocks = nil;
    if (!_terminated)
    {
        blocks = _blocks;
        _blocks = nil;
        
        _terminated = true;
    }
    pthread_mutex_unlock(&_lock);
    
    if (blocks) {
        blocks = nil;
    }
}

- (void)putNext:(id)next
{
    SSubscriberBlocks *blocks = nil;
    
    pthread_mutex_lock(&_lock);
    if (!_terminated) {
        blocks = _blocks;
    }
    pthread_mutex_unlock(&_lock);
    
    if (blocks && blocks->_next) {
        blocks->_next(next);
    }
}

- (void)putError:(id)error
{
    bool shouldDispose = false;
    SSubscriberBlocks *blocks = nil;
    
    pthread_mutex_lock(&_lock);
    if (!_terminated)
    {
        blocks = _blocks;
        _blocks = nil;
        
        shouldDispose = true;
        _terminated = true;
    }
    pthread_mutex_unlock(&_lock);
    
    if (blocks && blocks->_error) {
        blocks->_error(error);
    }
    
    if (shouldDispose)
        [self->_disposable dispose];
}

- (void)putCompletion
{
    bool shouldDispose = false;
    SSubscriberBlocks *blocks = nil;
    
    pthread_mutex_lock(&_lock);
    if (!_terminated)
    {
        blocks = _blocks;
        _blocks = nil;
        
        shouldDispose = true;
        _terminated = true;
    }
    pthread_mutex_unlock(&_lock);
    
    if (blocks && blocks->_completed)
        blocks->_completed();
    
    if (shouldDispose)
        [self->_disposable dispose];
}

- (void)dispose
{
    [self->_disposable dispose];
}

@end

@interface STracingSubscriber ()
{
    NSString *_name;
}

@end

@implementation STracingSubscriber

- (instancetype)initWithName:(NSString *)name next:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed
{
    self = [super initWithNext:next error:error completed:completed];
    if (self != nil)
    {
        _name = name;
    }
    return self;
}

@end
