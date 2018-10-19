//
//  SSignalKit.h
//  SSignalKit
//
//  Created by Peter on 31/01/15.
//  Copyright (c) 2015 Telegram. All rights reserved.
//

#if __IPHONE_OS_VERSION_MIN_REQUIRED
#import <UIKit/UIKit.h>
#else
#import <Foundation/Foundation.h>
#endif

//! Project version number for SSignalKit.
FOUNDATION_EXPORT double SSignalKitVersionNumber;

//! Project version string for SSignalKit.
FOUNDATION_EXPORT const unsigned char SSignalKitVersionString[];

// In this header, you should import all the public headers of your framework using statements like #import <SSignalKit/PublicHeader.h>

#import <CoaSSignalKit/SAtomic.h>
#import <CoaSSignalKit/SBag.h>
#import <CoaSSignalKit/SSignal.h>
#import <CoaSSignalKit/SSubscriber.h>
#import <CoaSSignalKit/SDisposable.h>
#import <CoaSSignalKit/SDisposableSet.h>
#import <CoaSSignalKit/SBlockDisposable.h>
#import <CoaSSignalKit/SMetaDisposable.h>
#import <CoaSSignalKit/SSignal+Single.h>
#import <CoaSSignalKit/SSignal+Mapping.h>
#import <CoaSSignalKit/SSignal+Multicast.h>
#import <CoaSSignalKit/SSignal+Meta.h>
#import <CoaSSignalKit/SSignal+Accumulate.h>
#import <CoaSSignalKit/SSignal+Dispatch.h>
#import <CoaSSignalKit/SSignal+Catch.h>
#import <CoaSSignalKit/SSignal+SideEffects.h>
#import <CoaSSignalKit/SSignal+Combine.h>
#import <CoaSSignalKit/SSignal+Timing.h>
#import <CoaSSignalKit/SSignal+Take.h>
#import <CoaSSignalKit/SSignal+Pipe.h>
#import <CoaSSignalKit/SMulticastSignalManager.h>
#import <CoaSSignalKit/STimer.h>
#import <CoaSSignalKit/SVariable.h>
