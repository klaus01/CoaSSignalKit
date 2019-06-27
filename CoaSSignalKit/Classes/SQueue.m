#import "SQueue.h"

static const void *SQueueSpecificKey = &SQueueSpecificKey;

@interface SQueue ()
{
    dispatch_queue_t _queue;
    void *_queueSpecific;
    bool _specialIsMainQueue;
}

@end

@implementation SQueue

+ (SQueue *)mainQueue
{
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[SQueue alloc] initWithNativeQueue:dispatch_get_main_queue() queueSpecific:NULL];
        queue->_specialIsMainQueue = true;
    });
    
    return queue;
}

+ (SQueue *)concurrentDefaultQueue
{
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[SQueue alloc] initWithNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) queueSpecific:NULL];
    });
    
    return queue;
}

+ (SQueue *)concurrentBackgroundQueue
{
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = [[SQueue alloc] initWithNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0) queueSpecific:NULL];
    });
    
    return queue;
}

+ (SQueue *)wrapConcurrentNativeQueue:(dispatch_queue_t)nativeQueue
{
    return [[SQueue alloc] initWithNativeQueue:nativeQueue queueSpecific:NULL];
}

- (instancetype)init
{
    dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
    dispatch_queue_set_specific(queue, SQueueSpecificKey, (__bridge void *)self, NULL);
    return [self initWithNativeQueue:queue queueSpecific:(__bridge void *)self];
}

- (SQueue *)initWithName:(NSString *)name qos:(dispatch_qos_class_t)qos {
    if (self = [super init]) {
        dispatch_queue_attr_t attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, qos, 0);
        dispatch_queue_t queue = dispatch_queue_create(name ? name.UTF8String : "", attr);
        _specialIsMainQueue = false;
        _queueSpecific = (__bridge void *)self;
        _queue = queue;
        dispatch_queue_set_specific(_queue, SQueueSpecificKey, (__bridge void *)self, NULL);
    }
    return self;
}

- (instancetype)initWithNativeQueue:(dispatch_queue_t)queue queueSpecific:(void *)queueSpecific
{
    self = [super init];
    if (self != nil)
    {
        _queue = queue;
        _queueSpecific = queueSpecific;
    }
    return self;
}

- (dispatch_queue_t)_dispatch_queue
{
    return _queue;
}

- (void)dispatch:(dispatch_block_t)block
{
    if (_queueSpecific != NULL && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
        block();
    else if (_specialIsMainQueue && [NSThread isMainThread])
        block();
    else
        dispatch_async(_queue, block);
}

- (void)dispatchSync:(dispatch_block_t)block
{
    if (_queueSpecific != NULL && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
        block();
    else if (_specialIsMainQueue && [NSThread isMainThread])
        block();
    else
        dispatch_sync(_queue, block);
}

- (void)dispatch:(dispatch_block_t)block synchronous:(bool)synchronous {
    if (_queueSpecific != NULL && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
        block();
    else if (_specialIsMainQueue && [NSThread isMainThread])
        block();
    else {
        if (synchronous) {
            dispatch_sync(_queue, block);
        } else {
            dispatch_async(_queue, block);
        }
    }
}

- (void)async:(dispatch_block_t)f {
    if (self.isCurrentQueue) {
        f();
    }else {
        dispatch_async(_queue, f);
    }
}

- (void)sync:(dispatch_block_t)f {
    if (self.isCurrentQueue) {
        f();
    }else {
        dispatch_sync(_queue, f);
    }
}

- (void)justDispatch:(dispatch_block_t)block {
    dispatch_async(_queue, block);
}

- (void)justDispatchWithQos:(dispatch_qos_class_t)qos f:(dispatch_block_t)f {
    dispatch_block_t qosBlock = dispatch_block_create_with_qos_class(DISPATCH_BLOCK_ENFORCE_QOS_CLASS, qos, 0, f);
    dispatch_async(_queue, qosBlock);
}

- (void)after:(double)delay f:(dispatch_block_t)f {
    dispatch_time_t time = DISPATCH_TIME_NOW + delay;
    dispatch_after(time, _queue, f);
}

- (bool)isCurrentQueue
{
    if (_queueSpecific != NULL && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific)
        return true;
    else if (_specialIsMainQueue && [NSThread isMainThread])
        return true;
    return false;
}

@end
