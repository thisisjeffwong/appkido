/*
 * AKDelegateMethodsSubtopic.m
 *
 * Created by Andy Lee on Wed Jul 03 2002.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "AKDelegateMethodsSubtopic.h"

#import "AKClassNode.h"
#import "AKDelegateMethodDoc.h"

@implementation AKDelegateMethodsSubtopic

//-------------------------------------------------------------------------
// AKSubtopic methods
//-------------------------------------------------------------------------

- (NSString *)subtopicName
{
    return
        [self includesAncestors]
        ? [@"ALL " stringByAppendingString:AKDelegateMethodsSubtopicName]
        : AKDelegateMethodsSubtopicName;
}

- (NSString *)stringToDisplayInSubtopicList
{
    return
        [self includesAncestors]
        ? [@"       " stringByAppendingString:[self subtopicName]]
        : [@"5.  " stringByAppendingString:[self subtopicName]];
}

//-------------------------------------------------------------------------
// AKMethodsSubtopic methods
//-------------------------------------------------------------------------

- (NSArray *)methodNodesForBehavior:(AKBehaviorNode *)behaviorNode
{
    if ([behaviorNode isClassNode])
    {
        return [(AKClassNode *)behaviorNode documentedDelegateMethods];
    }
    else
    {
        return [NSArray array];
    }
}

+ (id)methodDocClass
{
    return [AKDelegateMethodDoc class];
}

@end
