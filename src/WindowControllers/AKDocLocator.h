/*
 * AKDocLocator.h
 *
 * Created by Andy Lee on Tue May 27 2003.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import <Cocoa/Cocoa.h>

#import "AKSortable.h"

@class AKDoc;
@class AKTopic;

/*!
 *  Represents window states the user can navigate to in a browser window.
 */
@interface AKDocLocator : NSObject <AKSortable>

#pragma mark -
#pragma mark Factory methods

+ (id)withTopic:(AKTopic *)topic
   subtopicName:(NSString *)subtopicName
        docName:(NSString *)docName;

#pragma mark -
#pragma mark Preferences

+ (id)fromPrefDictionary:(NSDictionary *)prefDict;

- (NSDictionary *)asPrefDictionary;

#pragma mark -
#pragma mark Init/awake/dealloc

- (id)initWithTopic:(AKTopic *)topic
       subtopicName:(NSString *)subtopicName
            docName:(NSString *)docName;

#pragma mark -
#pragma mark Getters and setters

- (AKTopic *)topicToDisplay;

- (NSString *)subtopicName;

- (void)setSubtopicName:(NSString *)subtopicName;

- (NSString *)docName;

- (void)setDocName:(NSString *)docName;

- (NSString *)stringToDisplayInLists;

- (AKDoc *)docToDisplay;

#pragma mark -
#pragma mark Sorting

/*! *Should* be equivalent to using the -sortName mechanism, but faster. */
+ (void)sortArrayOfDocLocators:(NSMutableArray *)array;

@end
