#import <CoaSSignalKit/SDisposable.h>

@interface SSubscriber : NSObject <SDisposable>
{
}

@property (nonatomic, readonly) id<SDisposable> disposable;
@property (nonatomic, readonly) BOOL terminated;

- (instancetype)initWithNext:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed;

- (void)_assignDisposable:(id<SDisposable>)disposable;
- (void)_markTerminatedWithoutDisposal;

- (void)putNext:(id)next;
- (void)putError:(id)error;
- (void)putCompletion;

@end

@interface STracingSubscriber : SSubscriber

- (instancetype)initWithName:(NSString *)name next:(void (^)(id))next error:(void (^)(id))error completed:(void (^)())completed;

@end
