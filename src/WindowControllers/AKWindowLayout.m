/*
 * AKWindowLayout.m
 *
 * Created by Andy Lee on Sat Jun 14 2003.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "AKWindowLayout.h"

#import "AKFrameworkConstants.h"
#import "AKPrefUtils.h"

@implementation AKWindowLayout

//-------------------------------------------------------------------------
// Init/awake/dealloc
//-------------------------------------------------------------------------

- (id)init
{
    if ((self = [super init]))
    {
        _toolbarIsVisible = YES;
        _quicklistDrawerIsOpen = YES;
        _quicklistMode = 0;
        _frameworkPopupSelection = [AKFoundationFrameworkName retain];
        _searchIncludesClasses = YES;
        _searchIncludesMembers = YES;
        _searchIncludesFunctions = YES;
        _searchIncludesGlobals = YES;
        _searchIgnoresCase = YES;
    }

    return self;
}

- (void)dealloc
{
    [_frameworkPopupSelection release];

    [super dealloc];
}

//-------------------------------------------------------------------------
// Preferences
//-------------------------------------------------------------------------

+ (AKWindowLayout *)fromPrefDictionary:(NSDictionary *)prefDict
{
    if (prefDict == nil)
    {
        return nil;
    }

    AKWindowLayout *windowLayout =
        [[[AKWindowLayout alloc] init] autorelease];

    [windowLayout setWindowFrame:
        NSRectFromString([prefDict objectForKey:AKWindowFramePrefKey])];

    [windowLayout setToolbarIsVisible:
        [[prefDict objectForKey:AKToolbarIsVisiblePrefKey]
            boolValue]];

    [windowLayout setMiddleViewHeight:
        [[prefDict objectForKey:AKMiddleViewHeightPrefKey]
            floatValue]];

    [windowLayout setBrowserIsVisible:
        [[prefDict objectForKey:AKBrowserIsVisiblePrefKey]
            boolValue]];

    [windowLayout setBrowserFraction:
        [[prefDict objectForKey:AKBrowserFractionPrefKey]
            floatValue]];

    [windowLayout setNumberOfBrowserColumns:
        [[prefDict objectForKey:AKNumberOfBrowserColumnsPrefKey]
            intValue]];

    [windowLayout setQuicklistDrawerIsOpen:
        [[prefDict objectForKey:AKQuicklistDrawerIsOpenPrefKey]
            boolValue]];

    [windowLayout setQuicklistDrawerWidth:
        [[prefDict objectForKey:AKQuicklistDrawerWidthPrefKey]
            floatValue]];

    [windowLayout setQuicklistMode:
        [[prefDict objectForKey:AKQuicklistModePrefKey]
            intValue]];

    NSString *frameworkSelection =
        [prefDict objectForKey:AKFrameworkPopupSelectionPrefKey];
    if (frameworkSelection != nil)
    {
        [windowLayout setFrameworkPopupSelection:frameworkSelection];
    }

    [windowLayout setSearchIncludesClasses:
        [[prefDict objectForKey:AKIncludeClassesAndProtocolsPrefKey]
            boolValue]];

    [windowLayout setSearchIncludesMembers:
        [[prefDict objectForKey:AKIncludeMethodsPrefKey]
            boolValue]];

    [windowLayout setSearchIncludesFunctions:
        [[prefDict objectForKey:AKIncludeFunctionsPrefKey]
            boolValue]];

    [windowLayout setSearchIncludesGlobals:
        [[prefDict objectForKey:AKIncludeGlobalsPrefKey]
            boolValue]];

    [windowLayout setSearchIgnoresCase:
        [[prefDict objectForKey:AKIgnoreCasePrefKey]
            boolValue]];

    return windowLayout;
}

- (NSDictionary *)asPrefDictionary
{
    NSMutableDictionary *prefDict = [NSMutableDictionary dictionary];

    [prefDict
        setObject:NSStringFromRect(_windowFrame)
        forKey:AKWindowFramePrefKey];

    [prefDict
        setObject:[NSNumber numberWithBool:_toolbarIsVisible]
        forKey:AKToolbarIsVisiblePrefKey];

    [prefDict
        setObject:[NSNumber numberWithFloat:_middleViewHeight]
        forKey:AKMiddleViewHeightPrefKey];

    [prefDict
        setObject:[NSNumber numberWithBool:_browserIsVisible]
        forKey:AKBrowserIsVisiblePrefKey];

    [prefDict
        setObject:[NSNumber numberWithFloat:_browserFraction]
        forKey:AKBrowserFractionPrefKey];

    [prefDict
        setObject:[NSNumber numberWithInt:_numberOfBrowserColumns]
        forKey:AKNumberOfBrowserColumnsPrefKey];

    [prefDict
        setObject:[NSNumber numberWithBool:_quicklistDrawerIsOpen]
        forKey:AKQuicklistDrawerIsOpenPrefKey];

    [prefDict
        setObject:[NSNumber numberWithFloat:_quicklistDrawerWidth]
        forKey:AKQuicklistDrawerWidthPrefKey];

    [prefDict
        setObject:[NSNumber numberWithFloat:_quicklistMode]
        forKey:AKQuicklistModePrefKey];

    if (_frameworkPopupSelection)
    {
        [prefDict
            setObject:_frameworkPopupSelection
            forKey:AKFrameworkPopupSelectionPrefKey];
    }

    [prefDict
        setObject:[NSNumber numberWithBool:_searchIncludesClasses]
        forKey:AKIncludeClassesAndProtocolsPrefKey];

    [prefDict
        setObject:[NSNumber numberWithBool:_searchIncludesMembers]
        forKey:AKIncludeMethodsPrefKey];

    [prefDict
        setObject:[NSNumber numberWithBool:_searchIncludesFunctions]
        forKey:AKIncludeFunctionsPrefKey];

    [prefDict
        setObject:
            [NSNumber numberWithBool:_searchIncludesGlobals]
        forKey:AKIncludeGlobalsPrefKey];

    [prefDict
        setObject:[NSNumber numberWithBool:_searchIgnoresCase]
        forKey:AKIgnoreCasePrefKey];

    return prefDict;
}

//-------------------------------------------------------------------------
// Getters and setters
//-------------------------------------------------------------------------

- (NSRect)windowFrame
{
    return _windowFrame;
}

- (void)setWindowFrame:(NSRect)frame
{
    _windowFrame = frame;
}

- (BOOL)toolbarIsVisible
{
    return _toolbarIsVisible;
}

- (void)setToolbarIsVisible:(BOOL)flag
{
    _toolbarIsVisible = flag;
}

- (BOOL)browserIsVisible
{
    return _browserIsVisible;
}

- (void)setBrowserIsVisible:(BOOL)flag
{
    _browserIsVisible = flag;
}

- (float)browserFraction
{
    return _browserFraction;
}

- (void)setBrowserFraction:(float)height
{
    _browserFraction = height;
}

- (int)numberOfBrowserColumns
{
    return _numberOfBrowserColumns;
}

- (void)setNumberOfBrowserColumns:(int)numColumns
{
    _numberOfBrowserColumns = numColumns;
}

- (float)middleViewHeight
{
    return _middleViewHeight;
}

- (void)setMiddleViewHeight:(float)height
{
    _middleViewHeight = height;
}

- (BOOL)quicklistDrawerIsOpen
{
    return _quicklistDrawerIsOpen;
}

- (void)setQuicklistDrawerIsOpen:(BOOL)flag
{
    _quicklistDrawerIsOpen = flag;
}

- (float)quicklistDrawerWidth
{
    return _quicklistDrawerWidth;
}

- (void)setQuicklistDrawerWidth:(float)width
{
    _quicklistDrawerWidth = width;
}

- (int)quicklistMode
{
    return _quicklistMode;
}

- (void)setQuicklistMode:(int)mode
{
    _quicklistMode = mode;
}

- (NSString *)frameworkPopupSelection
{
    return _frameworkPopupSelection;
}

- (void)setFrameworkPopupSelection:(NSString *)frameworkName
{
    [frameworkName retain];
    [_frameworkPopupSelection release];
    _frameworkPopupSelection = frameworkName;
}

- (BOOL)searchIncludesClasses
{
    return _searchIncludesClasses;
}

- (void)setSearchIncludesClasses:(BOOL)flag
{
    _searchIncludesClasses = flag;
}

- (BOOL)searchIncludesMembers
{
    return _searchIncludesMembers;
}

- (void)setSearchIncludesMembers:(BOOL)flag
{
    _searchIncludesMembers = flag;
}

- (BOOL)searchIncludesFunctions
{
    return _searchIncludesFunctions;
}

- (void)setSearchIncludesFunctions:(BOOL)flag
{
    _searchIncludesFunctions = flag;
}

- (BOOL)searchIncludesGlobals
{
    return _searchIncludesGlobals;
}

- (void)setSearchIncludesGlobals:(BOOL)flag
{
    _searchIncludesGlobals = flag;
}

- (BOOL)searchIgnoresCase
{
    return _searchIgnoresCase;
}

- (void)setSearchIgnoresCase:(BOOL)flag
{
    _searchIgnoresCase = flag;
}

@end
