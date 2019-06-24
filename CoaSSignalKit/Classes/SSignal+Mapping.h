#import <CoaSSignalKit/SSignal.h>

@interface DistinctUntilChangedContext<__covariant T> : NSObject
@property (nonatomic, strong) T value;
@end

@interface SSignal (Mapping)

- (SSignal *)map:(id (^)(id))f;
- (SSignal *)filter:(bool (^)(id))f;
- (SSignal *)ignoreRepeated;
- (SSignal *)distinctUntilChanged;
- (SSignal *(^)(SSignal *))distinctUntilChangedisEqual:(BOOL(^)(id, id))isEqual;

@end
