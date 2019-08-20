#import <CoaSSignalKit/SSignal.h>

#import <CoaSSignalKit/SQueue.h>
#import <CoaSSignalKit/SThreadPool.h>

@interface SSignal (Dispatch)

- (SSignal *)deliverOn:(SQueue *)queue;
- (SSignal *)deliverOnThreadPool:(SThreadPool *)threadPool;
- (SSignal *)startOn:(SQueue *)queue;
- (SSignal *)runOn:(SQueue *)queue;
- (SSignal *)startOnThreadPool:(SThreadPool *)threadPool;
- (SSignal *)throttleOn:(SQueue *)queue delay:(NSTimeInterval)delay;
- (SSignal *)throttleToLastOn:(SQueue *)queue delay:(NSTimeInterval)delay;

@end
