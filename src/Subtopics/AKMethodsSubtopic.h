/*
 * AKMethodsSubtopic.h
 *
 * Created by Andy Lee on Tue Jul 09 2002.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "AKSubtopic.h"

@class AKBehaviorNode;

@interface AKMethodsSubtopic : AKSubtopic
{
@private
    // Do we include methods inherited from ancestor classes and declared
    // in protocols?
    BOOL _includesAncestors;
}

//-------------------------------------------------------------------------
// Init/awake/dealloc
//-------------------------------------------------------------------------

// Designated initializer
- (id)initIncludingAncestors:(BOOL)includeAncestors;

//-------------------------------------------------------------------------
// Getters and setters
//-------------------------------------------------------------------------

- (BOOL)includesAncestors;

// subclasses must override
- (AKBehaviorNode *)behaviorNode;

// Override this.  Returns method nodes for a single node -- no superclasses
// or protocols included.
- (NSArray *)methodNodesForBehavior:(AKBehaviorNode *)behaviorNode;

// Override this.
+ (id)methodDocClass;

@end

