#import <Foundation/Foundation.h>

#import <CoaSSignalKit/SThreadPoolTask.h>
#import <CoaSSignalKit/SThreadPoolQueue.h>

@interface SThreadPool : NSObject

- (instancetype)initWithThreadCount:(NSUInteger)threadCount threadPriority:(double)threadPriority;

- (void)addTask:(SThreadPoolTask *)task;

- (SThreadPoolQueue *)nextQueue;
- (void)_workOnQueue:(SThreadPoolQueue *)queue block:(void (^)())block;

@end
