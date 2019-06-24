#import <Foundation/Foundation.h>
#import <CoaSSignalKit/SSignalKit.h>

@interface Promise <__covariant T, NoError: NSError *> : NSObject

@property (nonatomic, readonly) SSignal *get;

- (id)initWithValue:(id)value;
- (void)set:(SSignal *)signal;

@end

@interface ValuePromise <__covariant T : id> : NSObject

@property (nonatomic, readonly) SSignal *get;

- (id)initWithValue:(id)value ignoreRepeated:(BOOL)ignoreRepeated;
- (id)initWithIgnoreRepeated:(BOOL)ignoreReapted;
- (void)set:(id)value;


@end
