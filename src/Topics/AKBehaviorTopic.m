/*
 * AKBehaviorTopic.m
 *
 * Created by Andy Lee on Mon May 26 2003.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "AKBehaviorTopic.h"

#import "DIGSLog.h"

@implementation AKBehaviorTopic

#pragma mark -
#pragma mark Init/awake/dealloc

- (void)dealloc
{
    [_subtopics release];

    [super dealloc];
}

#pragma mark -
#pragma mark Getters and setters

- (NSString *)behaviorName
{
    DIGSLogError_MissingOverride();
    return nil;
}

#pragma mark -
#pragma mark AKTopic methods

- (NSDictionary *)asPrefDictionary
{
    NSMutableDictionary *prefDict = [NSMutableDictionary dictionary];

    [prefDict setObject:[self className] forKey:AKTopicClassNamePrefKey];
    [prefDict setObject:[self behaviorName] forKey:AKBehaviorNamePrefKey];

    return prefDict;
}

- (NSInteger)numberOfSubtopics
{
    return [[self _subtopics] count];
}

- (AKSubtopic *)subtopicAtIndex:(NSInteger)subtopicIndex
{
    if (subtopicIndex < 0)
    {
        return nil;
    }

    return [[self _subtopics] objectAtIndex:subtopicIndex];
}

#pragma mark -
#pragma mark Subtopics

- (void)populateSubtopicsArray:(NSMutableArray *)array
{
    DIGSLogError_MissingOverride();
}

#pragma mark -
#pragma mark AKSortable methods

- (NSString *)sortName
{
    return [self behaviorName];
}

#pragma mark -
#pragma mark Private methods

- (NSArray *)_subtopics
{
    if (!_subtopics)
    {
        _subtopics = [[NSMutableArray alloc] init];
        [self populateSubtopicsArray:_subtopics];
    }

    return _subtopics;
}

@end
