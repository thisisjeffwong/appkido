/*
 * AKDocLocator.m
 *
 * Created by Andy Lee on Tue May 27 2003.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "AKDocLocator.h"

#import "AKTopic.h"
#import "AKSubtopic.h"
#import "AKDoc.h"

@implementation AKDocLocator

@synthesize topicToDisplay = _topic;
@synthesize subtopicName = _subtopicName;
@synthesize docName = _docName;

#pragma mark -
#pragma mark Factory methods

+ (id)withTopic:(AKTopic *)topic subtopicName:(NSString *)subtopicName docName:(NSString *)docName
{
    return [[[self alloc] initWithTopic:topic subtopicName:subtopicName docName:docName] autorelease];
}

#pragma mark -
#pragma mark Init/awake/dealloc

- (id)initWithTopic:(AKTopic *)topic subtopicName:(NSString *)subtopicName docName:(NSString *)docName
{
    if ((self = [super init]))
    {
        _topic = [topic retain];
        _subtopicName = [subtopicName copy];
        _docName = [docName copy];
    }

    return self;
}

- (void)dealloc
{
    [_topic release];
    [_subtopicName release];
    [_docName release];
    [_cachedDisplayString release];
    [_cachedSortName release];
    [_cachedDoc release];

    [super dealloc];
}

#pragma mark -
#pragma mark Getters and setters

- (void)setSubtopicName:(NSString *)subtopicName
{
    if (![_subtopicName isEqualToString:subtopicName])
    {
        [self _clearCachedObjects];
    }

    [_subtopicName autorelease];
    _subtopicName = [subtopicName copy];
}

- (void)setDocName:(NSString *)docName
{
    if (![_docName isEqualToString:docName])
    {
        [self _clearCachedObjects];
    }

    [_docName autorelease];
    _docName = [docName copy];
}

- (NSString *)stringToDisplayInLists
{
    // As described by the Character Palette:
    //      Name: LEFT-POINTING DOUBLE ANGLE QUOTATION MARK
    //      Unicode: 00AB
    //      UTF8: C2 AB
    static unichar kLeftDoubleAngle = 0x00AB;
    
    if (_cachedDisplayString == nil)
    {
        NSString *topicName = [_topic stringToDisplayInLists];

        if (_subtopicName == nil)
        {
            _cachedDisplayString = [topicName retain];
        }
        else if (_docName == nil)
        {
            _cachedDisplayString = [[NSString alloc] initWithFormat:@"%@  %C  %@",
                                    _subtopicName,  // [agl] displayed string?
                                    kLeftDoubleAngle,
                                    topicName];
        }
        else
        {
            _cachedDisplayString = [[NSString alloc] initWithFormat:@"%@  %C  %@",
                                    [[self docToDisplay] stringToDisplayInDocList],
                                    kLeftDoubleAngle,
                                    topicName];
        }

    }

    return _cachedDisplayString;
}

- (AKDoc *)docToDisplay
{
    if (_cachedDoc == nil)
    {
        AKSubtopic *subtopic = [_topic subtopicWithName:_subtopicName];

        _cachedDoc = [[subtopic docWithName:_docName] retain];
    }

    return _cachedDoc;
}

#pragma mark -
#pragma mark Sorting

// We want this to mirror the logic of -stringToDisplayInLists, which is
// too expensive to call directly.  That logic is:
//      *   If a doc locator has a doc name, then the string to display
//          (and therefore to sort on) is DocName+TopicName.
//      *   Otherwise, if the doc locator as a subtopic name, the string
//          to display is SubtopicName+TopicName.
//      *   Otherwise, the string to display is just TopicName.
//
// At most we'll have to do two string comparisons.  The work is in
// figuring out what two strings to compare first, and if those are equal,
// what two strings to compare next.
static
NSComparisonResult
compareDocLocators(AKDocLocator *locOne, AKDocLocator *locTwo, void *context)
{
    NSString *sOne = nil;
    NSString *sTwo = nil;

    // Get first shot at sOne.
    NSString *docNameOne = [locOne docName];
    NSString *subtopicNameOne = nil;
    NSString *topicNameOne = nil;

    if (docNameOne != nil)
    {
        sOne = docNameOne;
    }
    else
    {
        subtopicNameOne = [locOne subtopicName];

        if (subtopicNameOne != nil)
        {
            sOne = subtopicNameOne;
        }
        else
        {
            topicNameOne = [[locOne topicToDisplay] sortName];
            sOne = topicNameOne;
        }
    }

    // Get first shot at sTwo.
    NSString *docNameTwo = [locTwo docName];
    NSString *subtopicNameTwo = nil;
    NSString *topicNameTwo = nil;

    if (docNameTwo != nil)
    {
        sTwo = docNameTwo;
    }
    else
    {
        subtopicNameTwo = [locTwo subtopicName];

        if (subtopicNameTwo != nil)
        {
            sTwo = subtopicNameTwo;
        }
        else
        {
            topicNameTwo = [[locTwo topicToDisplay] sortName];
            sTwo = topicNameTwo;
        }
    }

    // Try the first comparison.
    NSComparisonResult result = [sOne caseInsensitiveCompare:sTwo];
    if (result != NSOrderedSame)
    {
        return result;
    }

    // If we got this far, we have to try the secondary comparison.
    if (sOne == topicNameOne)
    {
        // There is no secondary comparison string for locOne, so
        // locTwo is greater.
        return NSOrderedAscending;
    }

    if (sTwo == topicNameTwo)
    {
        // There is no secondary comparison string for locTwo, so
        // locOne is greater.
        return NSOrderedDescending;
    }

    // Both locOne and locTwo have a secondary comparison string,
    // namely their respective topic names.
    if (topicNameOne == nil)
    {
        topicNameOne = [[locOne topicToDisplay] sortName];
    }

    if (topicNameTwo == nil)
    {
        topicNameTwo = [[locTwo topicToDisplay] sortName];
    }

    return [topicNameOne caseInsensitiveCompare:topicNameTwo];
}

+ (void)sortArrayOfDocLocators:(NSMutableArray *)array
{
    [array sortUsingFunction:&compareDocLocators context:NULL];
}

#pragma mark -
#pragma mark AKPrefDictionary methods

+ (instancetype)fromPrefDictionary:(NSDictionary *)prefDict
{
    if (prefDict == nil)
    {
        return nil;
    }

    id topicPref = [prefDict objectForKey:AKTopicPrefKey];
    NSString *subtopicName = [prefDict objectForKey:AKSubtopicPrefKey];
    NSString *docName = [prefDict objectForKey:AKDocNamePrefKey];

    AKTopic *topic = [AKTopic fromPrefDictionary:topicPref];

    return [self withTopic:topic subtopicName:subtopicName docName:docName];
}

- (NSDictionary *)asPrefDictionary
{
    NSMutableDictionary *prefDict = [NSMutableDictionary dictionary];

    if (_topic)
    {
        [prefDict setObject:[_topic asPrefDictionary] forKey:AKTopicPrefKey];
    }

    if (_subtopicName)
    {
        [prefDict setObject:_subtopicName forKey:AKSubtopicPrefKey];
    }

    if (_docName)
    {
        [prefDict setObject:_docName forKey:AKDocNamePrefKey];
    }

    return prefDict;
}

#pragma mark -
#pragma mark AKSortable methods

- (NSString *)sortName
{
    if (_cachedSortName == nil)
    {
        NSString *topicName = [_topic sortName];

        if (_subtopicName == nil)
        {
            _cachedSortName = [topicName retain];
        }
        else
        {
            if (_docName == nil)
            {
                _cachedSortName = [[NSString alloc] initWithFormat:@"%@-%@", _subtopicName, topicName];
            }
            else
            {
                _cachedSortName = [[NSString alloc] initWithFormat:@"%@-%@", _docName, topicName];
            }
        }

    }

    return _cachedSortName;
}

#pragma mark -
#pragma mark NSObject methods

- (BOOL)isEqual:(id)anObject
{
    if (![anObject isKindOfClass:[AKDocLocator class]])
    {
        return NO;
    }

    // The "!=" tests take care of nil cases.

    // See if the subtopics have the same name.
    NSString *otherSubtopicName = [anObject subtopicName];
    if ((otherSubtopicName != _subtopicName) && ![otherSubtopicName isEqualToString:_subtopicName])
    {
        return NO;
    }

    // See if the docs have the same name.
    NSString *otherDocName = [anObject docName];
    if ((otherDocName != _docName) && ![otherDocName isEqualToString:_docName])
    {
        return NO;
    }

    // See if the topics match.
    AKTopic *otherTopic = [anObject topicToDisplay];
    if ((otherTopic != _topic) && ![otherTopic isEqual:_topic])
    {
        return NO;
    }

    // If we got this far, the history items match.
    return YES;
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@: [%@][%@][%@]>",
            [self className],
            [_topic pathInTopicBrowser],
            _subtopicName,
            _docName];
}

#pragma mark -
#pragma mark Private methods

- (void)_clearCachedObjects
{
    [_cachedDisplayString release];
    _cachedDisplayString = nil;

    [_cachedSortName release];
    _cachedSortName = nil;

    [_cachedDoc release];
    _cachedDoc = nil;
}

@end
