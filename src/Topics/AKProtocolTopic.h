/*
 * AKProtocolTopic.h
 *
 * Created by Andy Lee on Sun May 25 2003.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "AKBehaviorTopic.h"

@class AKProtocolNode;

@interface AKProtocolTopic : AKBehaviorTopic
{
@private
    AKProtocolNode *_protocolNode;
}

//-------------------------------------------------------------------------
// Factory methods
//-------------------------------------------------------------------------

+ (id)withProtocolNode:(AKProtocolNode *)protocolNode;

//-------------------------------------------------------------------------
// Init/awake/dealloc
//-------------------------------------------------------------------------

// Designated initializer
- (id)initWithProtocolNode:(AKProtocolNode *)protocolNode;

@end
