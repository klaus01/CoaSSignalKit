#import <CoaSSignalKit/SSignalKit.h>

@interface SignalTakeAction : NSObject

@property (nonatomic, readonly) BOOL passThrough;
@property (nonatomic, readonly) BOOL complete;

- (id)initWithPassThrough:(BOOL)passThrough complete:(BOOL)complete;

@end

@interface SSignal (Take)

- (SSignal *)take:(NSUInteger)count;
- (SSignal *)takeUtil:(SignalTakeAction *(^)(id))until;
- (SSignal *)takeLast;
- (SSignal *)takeUntilReplacement:(SSignal *)replacement;

@end
