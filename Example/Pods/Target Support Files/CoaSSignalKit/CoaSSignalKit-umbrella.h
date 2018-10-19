#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "SAtomic.h"
#import "SBag.h"
#import "SBlockDisposable.h"
#import "SDisposable.h"
#import "SDisposableSet.h"
#import "SMetaDisposable.h"
#import "SMulticastSignalManager.h"
#import "SQueue.h"
#import "SSignal+Accumulate.h"
#import "SSignal+Catch.h"
#import "SSignal+Combine.h"
#import "SSignal+Dispatch.h"
#import "SSignal+Mapping.h"
#import "SSignal+Meta.h"
#import "SSignal+Multicast.h"
#import "SSignal+Pipe.h"
#import "SSignal+SideEffects.h"
#import "SSignal+Single.h"
#import "SSignal+Take.h"
#import "SSignal+Timing.h"
#import "SSignal.h"
#import "SSignalKit.h"
#import "SSubscriber.h"
#import "SThreadPool.h"
#import "SThreadPoolQueue.h"
#import "SThreadPoolTask.h"
#import "STimer.h"
#import "SVariable.h"

FOUNDATION_EXPORT double CoaSSignalKitVersionNumber;
FOUNDATION_EXPORT const unsigned char CoaSSignalKitVersionString[];

