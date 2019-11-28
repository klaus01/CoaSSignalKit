#import <CoaSSignalKit/SDisposable.h>

id<SDisposable> SEmptyDisposable(void);

@interface SActionDisposable : NSObject<SDisposable>

- (instancetype)initWithAction:(void(^)(void))action;

@end
