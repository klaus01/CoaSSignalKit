#import <CoaSSignalKit/SSignal.h>

#import <CoaSSignalKit/SQueue.h>

@interface SSignal (Timing)

- (SSignal *)delay:(NSTimeInterval)seconds onQueue:(SQueue *)queue;
- (SSignal *)timeout:(NSTimeInterval)seconds onQueue:(SQueue *)queue orSignal:(SSignal *)signal;
- (SSignal *)wait:(NSTimeInterval)seconds;

@end
