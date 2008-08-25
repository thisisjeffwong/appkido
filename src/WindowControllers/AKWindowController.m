/*
 * AKWindowController.m
 *
 * Created by Andy Lee on Wed Jul 03 2002.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "AKWindowController.h"

#import <DIGSLog.h>

#import "AKFindPanelController.h"
#import "AKDocLocator.h"

#import "AKPrefUtils.h"
#import "AKViewUtils.h"
#import "AKDatabase.h"
#import "AKFileSection.h"
#import "AKClassNode.h"
#import "AKClassTopic.h"
#import "AKProtocolTopic.h"
#import "AKFormalProtocolsTopic.h"
#import "AKInformalProtocolsTopic.h"
#import "AKFunctionsTopic.h"
#import "AKGlobalsTopic.h"
#import "AKDoc.h"
#import "AKAppController.h"
#import "AKDocLocator.h"
#import "AKTopicBrowserController.h"
#import "AKDocListController.h"
#import "AKQuicklistController.h"
#import "AKWindowLayout.h"
#import "AKSavedWindowState.h"
#import "AKDocView.h"
#import "AKLinkResolver.h"
#import "AKOldLinkResolver.h"

//-------------------------------------------------------------------------
// Forward declarations of private methods
//-------------------------------------------------------------------------

@interface AKWindowController (Private)
- (void)_initToolbar;
- (NSString *)_tooltipForJumpToSuperclass;
- (void)_refreshNavigationButtons;
- (void)_refreshBackButton;
- (void)_refreshForwardButton;
- (void)_refreshSuperclassButton;
- (void)_navigateToHistoryIndex:(int)index;
- (void)_addHistoryItem:(AKDocLocator *)newHistoryItem;
- (AKTopic *)_currentTopic;
- (float)_computeBrowserFraction;
- (float)_computeBrowserHeight;
- (void)_rememberCurrentTextSelection;
@end


@implementation AKWindowController

//-------------------------------------------------------------------------
// Private constants -- toolbar identifiers
//-------------------------------------------------------------------------

static NSString *_AKToolbarID = @"AKToolbarID";

//-------------------------------------------------------------------------
// Init/awake/dealloc
//-------------------------------------------------------------------------

- (id)initWithDatabase:(AKDatabase *)database
{
    if ((self = [super init]))
    {
        _database = [database retain];

        int maxHistory =
            [AKPrefUtils intValueForPref:AKMaxHistoryPrefName];

        _windowHistory = [[NSMutableArray alloc] initWithCapacity:maxHistory];
        _windowHistoryIndex = -1;

        [NSBundle loadNibNamed:@"AppKiDo" owner:self];
    }

    return self;
}

- (id)init
{
    DIGSLogNondesignatedInitializer();
    [self release];
    return nil;
}

- (void)awakeFromNib
{
    // Set up the toolbar.
    [self _initToolbar];

    // Get the initial value for the height of the browser.
    _browserFractionWhenVisible = [self _computeBrowserFraction];

    // Initialize my subcontrollers.
    [_topicBrowserController doAwakeFromNib];
    [_quicklistController doAwakeFromNib];

    // Apply display preferences *after* all awake-from-nibs have been
    // done, because DIGSMarginViews have to have fully initialized
    // themselves before we go resizing things or swapping subviews around.
    [self applyUserPreferences];

    // Select NSObject.
    _windowHistoryIndex = -1;
    [_windowHistory removeAllObjects];
    AKClassNode *classNode = [_database classWithName:@"NSObject"];
    [self jumpToTopic:[AKClassTopic topicWithClassNode:classNode inDatabase:_database]];
}

- (void)dealloc
{
    [_database release];

    [_windowHistory release];

    [_topicBrowserController release];
    [_quicklistController release];
    [[_quicklistDrawer contentView] release];
    [_quicklistDrawer release];
    [_docTextMenu release];
    [_backMenu release];
    [_forwardMenu release];

    [super dealloc];
}

//-------------------------------------------------------------------------
// Getters and setters
//-------------------------------------------------------------------------

- (AKDatabase *)database
{
    return _database;
}

//-------------------------------------------------------------------------
// User preferences
//-------------------------------------------------------------------------

- (void)applyUserPreferences
{
    [_topicBrowserController applyUserPreferences];
    [_quicklistController applyUserPreferences];
}

//-------------------------------------------------------------------------
// Navigation
//-------------------------------------------------------------------------

- (AKDocLocator *)currentHistoryItem
{
    return
        (_windowHistoryIndex < 0)
        ? nil
        : [_windowHistory objectAtIndex:_windowHistoryIndex];
}

- (void)openWindowWithQuicklistDrawer:(BOOL)drawerIsOpen
{
    // Display the window and set the drawer state, in that order.  Can't
    // set drawer state on an undisplayed window.
    [[_topicBrowser window] makeKeyAndOrderFront:nil];

    if (drawerIsOpen)
    {
        [_quicklistDrawer openOnEdge:NSMinXEdge];
    }

    // The shadow seems to get screwed up by the drawer stuff, so force it
    // to get redrawn.  Note that -invalidateShadow does not exist in
    // 10.1, so use -setHasShadow: instead.
    [[_topicBrowser window] setHasShadow:NO];
    [[_topicBrowser window] setHasShadow:YES];
}

- (void)jumpToTopic:(AKTopic *)obj
{
    AKDocLocator *currentItem = [self currentHistoryItem];

    [self
        jumpToTopic:obj
        subtopicName:[currentItem subtopicName]
        docName:[currentItem docName]];
}

- (void)jumpToSubtopicWithName:(NSString *)subtopicName
{
    AKDocLocator *currentItem = [self currentHistoryItem];

    [self
        jumpToTopic:[currentItem topicToDisplay]
        subtopicName:subtopicName
        docName:[currentItem docName]];
}

- (void)jumpToDocName:(NSString *)docName
{
    AKDocLocator *currentItem = [self currentHistoryItem];

    [self
        jumpToTopic:[currentItem topicToDisplay]
        subtopicName:[currentItem subtopicName]
        docName:docName];
}

- (void)jumpToDocLocator:(AKDocLocator *)docLocator
{
    [self
        jumpToTopic:[docLocator topicToDisplay]
        subtopicName:[docLocator subtopicName]
        docName:[docLocator docName]];
}

// all the other "jumpTo" methods must come through here
- (void)jumpToTopic:(AKTopic *)topic
    subtopicName:(NSString *)subtopicName
    docName:(NSString *)docName
{
    if (topic == nil)
    {
        DIGSLogInfo(@"can't navigate to a nil topic");
        return;
    }

    [self _rememberCurrentTextSelection];

    AKDocLocator *newHistoryItem =
        [AKDocLocator
            withTopic:topic
            subtopicName:subtopicName
            docName:docName];

    [_topicBrowserController
        navigateFrom:[self currentHistoryItem]
        to:newHistoryItem];
    [self _addHistoryItem:newHistoryItem];
}

- (BOOL)jumpToLinkURL:(NSURL *)linkURL
{
    NSString *filePath =
        [[[[self currentHistoryItem] docToDisplay] fileSection] filePath];
    NSURL *docFileURL = [NSURL fileURLWithPath:filePath];
    linkURL = [NSURL URLWithString:[linkURL relativeString] relativeToURL:docFileURL];

    // Let somebody else handle the URL if it's not a "file:/" URL.
    if (![linkURL isFileURL])
    {
        DIGSLogDebug(@"let somebody else handle non-file url %@", linkURL);
        return NO;
    }

    // If the link can be converted to an AKDocLocator, jump to that
    // locator.  Otherwise, try opening the file in the user's browser.
    AKDocLocator *linkDestination =
        [[AKLinkResolver linkResolverWithDatabase:_database]
            docLocatorForURL:linkURL];

    if (linkDestination == nil)
    {
        DIGSLogDebug(@"resorting to AKOldLinkResolver for %@", linkURL);
        linkDestination =
            [[AKOldLinkResolver linkResolverWithDatabase:_database]
                docLocatorForURL:linkURL];
    }

    if (linkDestination)
    {
        [self jumpToDocLocator:linkDestination];
        [self focusOnDocListTable];
        [[_topLevelSplitView window] makeKeyAndOrderFront:nil];
        return YES;
    }
    else if ([[NSWorkspace sharedWorkspace] openURL:linkURL])
    {
        DIGSLogDebug(@"NSWorkspace opened URL [%@]", linkURL);
        return YES;
    }
    else
    {
        DIGSLogWarning(@"NSWorkspace couldn't open URL [%@]", linkURL);
        return NO;
    }
}

- (NSView *)focusOnDocView
{
    return [_docView grabFocus];
}

- (void)focusOnDocListTable
{
    [_docListController focusOnDocListTable];
}

- (void)bringToFront
{
    [[_topicBrowser window] makeKeyAndOrderFront:nil];
}

- (void)searchForString:(NSString *)aString {
    int state = [_quicklistDrawer state];
    if ((state == NSDrawerClosedState) || (state == NSDrawerClosingState))
    {
        [self toggleQuicklistDrawer:nil];
    }
    [_quicklistController searchForString:aString];
}

//-------------------------------------------------------------------------
// Window layout
//-------------------------------------------------------------------------

- (void)takeWindowLayoutFrom:(AKWindowLayout *)windowLayout
{
    if (windowLayout == nil)
    {
        return;
    }

    // Apply the specified window frame.
    [[_topicBrowser window]
        setFrame:[windowLayout windowFrame] display:NO];

    // Restore the visibility of the toolbar.
    [[[_topicBrowser window] toolbar]
        setVisible:[windowLayout toolbarIsVisible]];

    // Apply the new browser fraction.  Note that -_computerBrowserHeight
    // uses the _browserFractionWhenVisible ivar, so we make sure to set
    // the ivar first.
    _browserFractionWhenVisible = [windowLayout browserFraction];
    if (([_topicBrowser frame].size.height > 0.0)
        && [windowLayout browserIsVisible])
    {
        [_topLevelSplitView
            ak_setHeight:[self _computeBrowserHeight]
            ofSubview:_topicBrowser];
    }
    else
    {
        [_topLevelSplitView ak_setHeight:0.0 ofSubview:_topicBrowser];
    }

    // Restore the state of the inner split view.
    [_innerSplitView
        ak_setHeight:[windowLayout middleViewHeight]
        ofSubview:_middleView];

    // Restore the number of browser columns.
    if ([windowLayout numberOfBrowserColumns])
    {
        [_topicBrowser setMaxVisibleColumns:
            [windowLayout numberOfBrowserColumns]];
    }
    else
    {
        [_topicBrowser setMaxVisibleColumns:3];
    }

    // Restore the state of the Quicklist drawer.
    NSSize drawerContentSize = [_quicklistDrawer contentSize];

    drawerContentSize.width = [windowLayout quicklistDrawerWidth];
    [_quicklistDrawer setContentSize:drawerContentSize];

    // Restore the internal state of the Quicklist.
    [_quicklistController takeWindowLayoutFrom:windowLayout];
}

- (void)putWindowLayoutInto:(AKWindowLayout *)windowLayout
{
    if (windowLayout == nil)
    {
        return;
    }

    // Remember the current window frame.
    [windowLayout setWindowFrame:[[_topicBrowser window] frame]];

    // Remember the visibility of the toolbar.
    [windowLayout setToolbarIsVisible:
        [[[_topicBrowser window] toolbar] isVisible]];

    // Remember the state of the inner split view.
    [windowLayout setMiddleViewHeight:([_middleView frame].size.height)];

    // Remember the state of the browser.
    [windowLayout setBrowserIsVisible:
        ([_topicBrowser frame].size.height > 0)];
    [windowLayout setBrowserFraction:_browserFractionWhenVisible];
    [windowLayout setNumberOfBrowserColumns:
        [_topicBrowser maxVisibleColumns]];

    // Remember the state of the Quicklist drawer.
    int state = [_quicklistDrawer state];
    BOOL drawerIsOpen =
        (state == NSDrawerOpenState) || (state == NSDrawerOpeningState);

    [windowLayout setQuicklistDrawerIsOpen:drawerIsOpen];
    [windowLayout setQuicklistDrawerWidth:
        ([_quicklistDrawer contentSize].width)];

    // Remember the internal state of the Quicklist.
    [_quicklistController putWindowLayoutInto:windowLayout];
}

- (void)putSavedWindowStateInto:(AKSavedWindowState *)savedWindowState
{
    AKWindowLayout *windowLayout =
        [[[AKWindowLayout alloc] init] autorelease];

    [self putWindowLayoutInto:windowLayout];

    [savedWindowState setSavedWindowLayout:windowLayout];
    [savedWindowState setSavedDocLocator:[self currentHistoryItem]];
}

//-------------------------------------------------------------------------
// UI item validation
//-------------------------------------------------------------------------

- (BOOL)validateItem:(id)anItem
{
    SEL itemAction = [anItem action];

    if (itemAction == @selector(revealDocFileInFinder:))
    {
        return ([[self currentHistoryItem] docName] != nil);
    }
    else if (itemAction == @selector(navigateBack:))
    {
        return (_windowHistoryIndex > 0);
    }
    else if (itemAction == @selector(navigateForward:))
    {
        return (_windowHistoryIndex < ((int)[_windowHistory count] - 1));
    }
    else if ((itemAction == @selector(doBackMenuAction:))
        || (itemAction == @selector(doForwardMenuAction:)))
    {
        return YES;
    }
    else if ((itemAction == @selector(jumpToSuperclass:))
        || (itemAction == @selector(jumpToAncestorClass:)))
    {
        return ([[self _currentTopic] parentClassOfTopic] != nil);
    }
    else if (itemAction == @selector(jumpToSubtopicWithIndexFromTag:))
    {
        return YES;
    }
    else if ((itemAction == @selector(jumpToFrameworkFormalProtocols:))
        || (itemAction == @selector(jumpToFrameworkInformalProtocols:))
        || (itemAction == @selector(jumpToFrameworkFunctions:))
        || (itemAction == @selector(jumpToFrameworkGlobals:))
        || (itemAction == @selector(jumpToDocLocatorRepresentedBy:))
        || (itemAction == @selector(copyDocTextURL:))
        || (itemAction == @selector(openDocURLInBrowser:))
        || (itemAction == @selector(rememberWindowLayout:)))
    {
        return YES;
    }
    else if (itemAction == @selector(addTopicToFavorites:))
    {
        AKTopic *currentTopic = [self _currentTopic];

        // Update the menu item title to reflect what's currently
        // selected in the topic browser.
        if ([anItem isKindOfClass:[NSMenuItem class]])
        {
            NSString *topicName =
                [currentTopic stringToDisplayInTopicBrowser];
            NSString *menuTitle =
                [NSString
                    stringWithFormat:@"Add \"%@\" to Favorites",
                    topicName];

            [anItem setTitle:menuTitle];
        }

        // Enable the item if the selected topic isn't already a
        // favorite.
        AKAppController *appController = [NSApp delegate];
        NSArray *favoritesList = [appController favoritesList];
        AKDocLocator *proposedFavorite =
            [AKDocLocator
                withTopic:currentTopic
                subtopicName:nil
                docName:nil];

        if ([favoritesList containsObject:proposedFavorite])
        {
            return NO;
        }
        else
        {
            return YES;
        }
    }
    else if (itemAction == @selector(toggleQuicklistDrawer:))
    {
        if ([anItem isKindOfClass:[NSMenuItem class]])
        {
            int state = [_quicklistDrawer state];

            if ((state == NSDrawerClosedState)
                || (state == NSDrawerClosingState))
            {
                [anItem setTitle:@"Show Quicklist"];
            }
            else
            {
                [anItem setTitle:@"Hide Quicklist"];
            }
        }

        return YES;
    }
    else if (itemAction == @selector(toggleBrowserVisible:))
    {
        if ([anItem isKindOfClass:[NSMenuItem class]])
        {
            if (([_topicBrowser frame].size.height == 0.0)
                && (_browserFractionWhenVisible > 0.0))
            {
                [anItem setTitle:@"Show Browser"];
            }
            else
            {
                [anItem setTitle:@"Hide Browser"];
            }
        }

        return YES;
    }
    else if (itemAction == @selector(addBrowserColumn:))
    {
        return ([_topicBrowser frame].size.height > 0.0);
    }
    else if (itemAction == @selector(removeBrowserColumn:))
    {
        if ([_topicBrowser frame].size.height > 0.0)
        {
            return ([_topicBrowser maxVisibleColumns] > 2);
        }
        else
        {
            return NO;
        }
    }
    else if ([_topicBrowserController validateItem:anItem])
    {
        return YES;
    }
    else
    {
        return [_quicklistController validateItem:anItem];
    }
}

//-------------------------------------------------------------------------
// Action methods -- window layout
//-------------------------------------------------------------------------

- (IBAction)rememberWindowLayout:(id)sender
{
    AKWindowLayout *windowLayout =
        [[[AKWindowLayout alloc] init] autorelease];
    [self putWindowLayoutInto:windowLayout];

    NSDictionary *prefDictionary = [windowLayout asPrefDictionary];
    [AKPrefUtils
        setDictionaryValue:prefDictionary
        forPref:AKLayoutForNewWindowsPrefName];
}

- (IBAction)addBrowserColumn:(id)sender
{
    [_topicBrowserController addBrowserColumn:nil];
}

- (IBAction)removeBrowserColumn:(id)sender
{
    [_topicBrowserController removeBrowserColumn:nil];
}

- (IBAction)jumpToSubtopicWithIndexFromTag:(id)sender
{
    [_topicBrowserController jumpToSubtopicWithIndex:[sender tag]];
}

- (IBAction)toggleBrowserVisible:(id)sender
{
    NSRect browserFrame = [_topicBrowser frame];

    if (browserFrame.size.height == 0.0)
    {
        [_topLevelSplitView
            ak_setHeight:[self _computeBrowserHeight]
            ofSubview:_topicBrowser];
    }
    else
    {
        [_topLevelSplitView ak_setHeight:0.0 ofSubview:_topicBrowser];
    }

// [agl] KLUDGE -- for some reason the scroll view does not retile
// automatically, so I force it here; the reason I traverse all subviews
// is because the internal view hierarchy of WebView is not exposed
    NSMutableArray *allSubviews =
        [NSMutableArray arrayWithArray:[_docView subviews]];
    unsigned index = 0;

    while (index < [allSubviews count])
    {
        NSView *view = [allSubviews objectAtIndex:index];

        [allSubviews addObjectsFromArray:[view subviews]];

        index++;
    }

    for (index = 0; index < [allSubviews count]; index++)
    {
        NSView *view = [allSubviews objectAtIndex:index];

        if ([view isKindOfClass:[NSScrollView class]])
        {
            [(NSScrollView *)view tile];
        }
    }
}

- (IBAction)showBrowser:(id)sender
{
    if ([_topicBrowser frame].size.height == 0.0)
    {
        [self toggleBrowserVisible:nil];
    }
}

- (IBAction)toggleQuicklistDrawer:(id)sender
{
    int state = [_quicklistDrawer state];

    if ((state == NSDrawerClosedState) || (state == NSDrawerClosingState))
    {
        [_quicklistDrawer openOnEdge:NSMinXEdge];
    }
    else
    {
        [_quicklistDrawer close];
    }
}

//-------------------------------------------------------------------------
// Action methods -- navigation
//-------------------------------------------------------------------------

- (IBAction)navigateBack:(id)sender
{
    if (_windowHistoryIndex > 0)
    {
        [self _navigateToHistoryIndex:(_windowHistoryIndex - 1)];
    }
}

- (IBAction)navigateForward:(id)sender
{
    if (_windowHistoryIndex < ((int)[_windowHistory count] - 1))
    {
        [self _navigateToHistoryIndex:(_windowHistoryIndex + 1)];
    }
}

- (IBAction)doBackMenuAction:(id)sender
{
    // Figure out how far back in history to navigate.
    int offset = [_backMenu indexOfItem:(NSMenuItem *)sender] + 1;

    // Do the navigation.
    [self _navigateToHistoryIndex:(_windowHistoryIndex - offset)];
}

- (IBAction)doForwardMenuAction:(id)sender
{
    // Figure out how far forward in history to navigate.
    int offset = [_forwardMenu indexOfItem:(NSMenuItem *)sender] + 1;

    // Do the navigation.
    [self _navigateToHistoryIndex:(_windowHistoryIndex + offset)];
}

- (IBAction)jumpToSuperclass:(id)sender
{
    AKClassNode *superclassNode = [[self _currentTopic] parentClassOfTopic];

    if (superclassNode)
    {
        [self jumpToTopic:[AKClassTopic topicWithClassNode:superclassNode inDatabase:_database]];
    }
}

// We expect sender to be an NSMenuItem.
- (IBAction)jumpToAncestorClass:(id)sender
{
    AKClassNode * classNode = [[self _currentTopic] parentClassOfTopic];
    int numberOfSuperlevels;
    int i;

    if (classNode == nil)
    {
        return;
    }

    // Figure out how far back in our ancestry to jump.
    numberOfSuperlevels = [_superclassesMenu indexOfItem:sender];

    // Figure out what class that means to jump to.
    for (i = 0; i < numberOfSuperlevels; i++)
    {
        classNode = [classNode parentClass];
    }

    // Do the jump.
    [self jumpToTopic:[AKClassTopic topicWithClassNode:classNode inDatabase:_database]];
}

- (IBAction)jumpToFrameworkFormalProtocols:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]])
    {
        NSString *fwName = [[sender menu] title];

        [self jumpToTopic:[AKFormalProtocolsTopic topicWithFramework:fwName inDatabase:_database]];

        [self showBrowser:nil];
    }
}

- (IBAction)jumpToFrameworkInformalProtocols:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]])
    {
        NSString *fwName = [[sender menu] title];

        [self jumpToTopic:[AKInformalProtocolsTopic topicWithFramework:fwName inDatabase:_database]];
        [self showBrowser:nil];
    }
}

- (IBAction)jumpToFrameworkFunctions:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]])
    {
        NSString *fwName = [[sender menu] title];

        [self jumpToTopic:[AKFunctionsTopic topicWithFramework:fwName inDatabase:_database]];
        [self showBrowser:nil];
    }
}

- (IBAction)jumpToFrameworkGlobals:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]])
    {
        NSString *fwName = [[sender menu] title];

        [self jumpToTopic:[AKGlobalsTopic topicWithFramework:fwName inDatabase:_database]];
        [self showBrowser:nil];
    }
}

- (IBAction)jumpToDocLocatorRepresentedBy:(id)sender
{
    if ([sender isKindOfClass:[NSMenuItem class]])
    {
        [self jumpToDocLocator:[sender representedObject]];
    }
}

- (IBAction)addTopicToFavorites:(id)sender
{
    [(AKAppController *)[NSApp delegate]
        addFavorite:
            [AKDocLocator
                withTopic:[self _currentTopic]
                subtopicName:nil
                docName:nil]];
}

- (IBAction)findNext:(id)sender
{
    [[AKFindPanelController sharedInstance] findNext:nil];
}

- (IBAction)findPrevious:(id)sender
{
    [[AKFindPanelController sharedInstance] findPrevious:nil];
}

- (IBAction)revealDocFileInFinder:(id)sender
{
    // Figure out what file is being displayed in the doc view.
    AKDoc *doc = [_docListController currentDoc];

    if (doc == nil)
    {
        return;
    }

    AKFileSection *fileSection = [doc fileSection];

    if (fileSection == nil)
    {
        return;
    }

    // Construct and execute an AppleScript command that asks the Finder
    // to reveal the file.
    NSString *appleScriptCommand =
        [NSString
            stringWithFormat:
                @"tell application \"Finder\"\n"
                @"    reveal posix file \"%@\"\n"
                @"    activate\n"
                @"end tell",
                [fileSection filePath]];
    NSAppleScript *appleScript =
        [[[NSAppleScript alloc] initWithSource:appleScriptCommand]
            autorelease];
    NSDictionary *errorInfo = nil;
    NSAppleEventDescriptor *appleEventDescriptor =
        [appleScript executeAndReturnError:&errorInfo];

    if (appleEventDescriptor == nil)
    {
        DIGSLogError(@"Error executing AppleScript: %@", errorInfo);
    }
}

- (IBAction)copyDocTextURL:(id)sender
{
    NSString *filePath =
        [[[[self currentHistoryItem] docToDisplay] fileSection] filePath];
    NSURL *docFileURL = [NSURL fileURLWithPath:filePath];
    NSURL *fileURL = [[docFileURL absoluteURL] standardizedURL];

    NSString *urlString = [fileURL absoluteString];

    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSArray *pasteboardTypes = [NSArray arrayWithObject:NSStringPboardType];

    [pasteboard declareTypes:pasteboardTypes owner:nil];
    [pasteboard setString:urlString forType:NSStringPboardType];
}

- (IBAction)openDocURLInBrowser:(id)sender
{
    NSString *filePath =
        [[[[self currentHistoryItem] docToDisplay] fileSection] filePath];
    NSURL *docFileURL = [NSURL fileURLWithPath:filePath];
    NSURL *fileURL = [[docFileURL absoluteURL] standardizedURL];

    [[NSWorkspace sharedWorkspace] openURL:fileURL];
}

//-------------------------------------------------------------------------
// Action methods -- search (forwarded to the quicklist controller)
//-------------------------------------------------------------------------

- (IBAction)selectSearchField:(id)sender
{
    int state = [_quicklistDrawer state];
    if ((state == NSDrawerClosedState) || (state == NSDrawerClosingState))
    {
        [self toggleQuicklistDrawer:nil];
    }

    [_quicklistController selectSearchField:sender];
}

- (IBAction)selectPreviousSearchResult:(id)sender
{
    int state = [_quicklistDrawer state];
    if ((state == NSDrawerClosedState) || (state == NSDrawerClosingState))
    {
        [self toggleQuicklistDrawer:nil];
    }

    [_quicklistController selectPreviousSearchResult:sender];
}

- (IBAction)selectNextSearchResult:(id)sender
{
    int state = [_quicklistDrawer state];
    if ((state == NSDrawerClosedState) || (state == NSDrawerClosingState))
    {
        [self toggleQuicklistDrawer:nil];
    }

    [_quicklistController selectNextSearchResult:sender];
}

//-------------------------------------------------------------------------
// NSMenuValidation protocol methods
//-------------------------------------------------------------------------

- (BOOL)validateMenuItem:(NSMenuItem *)aCell
{
    return [self validateItem:aCell];
}

//-------------------------------------------------------------------------
// NSToolbarItemValidation protocol methods
//-------------------------------------------------------------------------

- (BOOL)validateToolbarItem:(NSToolbarItem *)theItem
{
    BOOL isValid = [self validateItem:theItem];

    if (isValid && ([theItem action] == @selector(jumpToSuperclass:)))
    {
        [theItem setToolTip:[self _tooltipForJumpToSuperclass]];
    }

    return isValid;
}

//-------------------------------------------------------------------------
// NSSplitView delegate methods
//-------------------------------------------------------------------------

- (void)splitViewDidResizeSubviews:(NSNotification *)aNotification
{
    if ([aNotification object] == _topLevelSplitView)
    {
        float browserHeight = [_topicBrowser frame].size.height;

        if (browserHeight != 0.0)
        {
            _browserFractionWhenVisible = [self _computeBrowserFraction];
        }
    }
}

//-------------------------------------------------------------------------
// NSWindow delegate methods
//-------------------------------------------------------------------------

// FIXME [agl] this is a workaround to either a bug or something I don't
// understand; when the prefs panel is dismissed, the AppKiDo window below
// it doesn't come front (despite becoming key) if there was an intervening
// window from another app; weird because if change the prefs panel to an
// NSWindow, it works as expected; anyway, this kludge forces the window
// front when it becomes key
- (void)windowDidBecomeKey:(NSNotification *)aNotification
{
    [(NSWindow *)[aNotification object] orderFront:nil];
}

@end

//-------------------------------------------------------------------------
// Private methods
//-------------------------------------------------------------------------

@implementation AKWindowController (Private)

- (void)_initToolbar
{
    NSToolbar *toolbar =
        [[[NSToolbar alloc] initWithIdentifier:_AKToolbarID] autorelease];

    // Set up toolbar properties. 
    [toolbar setAllowsUserCustomization:YES];
    [toolbar setAutosavesConfiguration:YES];
    [toolbar setDisplayMode:NSToolbarDisplayModeIconAndLabel];

    // We are the delegate.
    [toolbar setDelegate:self];

    // Attach the toolbar to the browser window.
    [[_topicBrowser window] setToolbar:toolbar];
}

- (NSString *)_tooltipForJumpToSuperclass
{
    return
        [NSString stringWithFormat:
            @"Go to superclass (%@)"
                @"\n(Control-click or right-click for menu)",
            [[[self _currentTopic] parentClassOfTopic] nodeName]];
}

- (void)_refreshNavigationButtons
{
    [self _refreshBackButton];
    [self _refreshForwardButton];
    [self _refreshSuperclassButton];
}

- (void)_refreshBackButton
{
    int i;

    // Enable or disable the Back button as appropriate.
    [_backButton setEnabled:(_windowHistoryIndex > 0)];

    // Empty the Back button's contextual menu.
    while ([_backMenu numberOfItems] > 0)
    {
        [_backMenu removeItemAtIndex:0];
    }

    // Reconstruct the Back button's contextual menu.
    for (i = _windowHistoryIndex - 1; i >= 0; i--)
    {
        AKDocLocator *historyItem = [_windowHistory objectAtIndex:i];
        NSString *menuItemName = [historyItem stringToDisplayInLists];

        [_backMenu addItemWithTitle:menuItemName
            action:@selector(doBackMenuAction:)
            keyEquivalent:@""];
    }
}

- (void)_refreshForwardButton
{
    int historySize = (int)[_windowHistory count];
    int i;

    // Enable or disable the Forward button as appropriate.
    [_forwardButton setEnabled:(_windowHistoryIndex < historySize - 1)];

    // Empty the Forward button's contextual menu.
    while ([_forwardMenu numberOfItems] > 0)
    {
        [_forwardMenu removeItemAtIndex:0];
    }

    // Reconstruct the Forward button's contextual menu.
    for (i = _windowHistoryIndex + 1; i < historySize; i++)
    {
        AKDocLocator *historyItem = [_windowHistory objectAtIndex:i];
        NSString *menuItemName = [historyItem stringToDisplayInLists];

        [_forwardMenu addItemWithTitle:menuItemName
            action:@selector(doForwardMenuAction:)
            keyEquivalent:@""];
    }
}

- (void)_refreshSuperclassButton
{
    AKClassNode *parentClass =
        [[self _currentTopic] parentClassOfTopic];

    // Enable or disable the Superclass button as appropriate.
    [_superclassButton setEnabled:(parentClass != nil)];
    if ([_superclassButton isEnabled])
    {
        [_superclassButton setToolTip:[self _tooltipForJumpToSuperclass]];
    }

    // Empty the Superclass button's contextual menu.
    while ([_superclassesMenu numberOfItems] > 0)
    {
        [_superclassesMenu removeItemAtIndex:0];
    }

    // Reconstruct the Superclass button's contextual menu.
    AKClassNode *ancestorNode = parentClass;
    while (ancestorNode != nil)
    {
        [_superclassesMenu addItemWithTitle:[ancestorNode nodeName]
            action:@selector(jumpToAncestorClass:)
            keyEquivalent:@""];

        ancestorNode = [ancestorNode parentClass];
    }
}

// All the history navigation methods come through here.
- (void)_navigateToHistoryIndex:(int)index
{
    if ((index < 0) || (index >= (int)[_windowHistory count]))
    {
        return;
    }

    // Navigate to the specified history item.
    AKDocLocator *historyItem = [_windowHistory objectAtIndex:index];

    [self _rememberCurrentTextSelection];
    [_topicBrowserController navigateFrom:nil to:historyItem];

    // Update our marker index into the history array.
    _windowHistoryIndex = index;
    DIGSLogDebug(@"jumped to history index %d, history count=%d",
        _windowHistoryIndex, [_windowHistory count]);

    // Update miscellaneous parts of the UI that reflect our current
    // position in history.
    [self _refreshNavigationButtons];
    [[_topicBrowser window] setTitle:[historyItem stringToDisplayInLists]];
}

- (void)_addHistoryItem:(AKDocLocator *)newHistoryItem
{
    AKDocLocator *currentHistoryItem = [self currentHistoryItem];
    int maxHistory = [AKPrefUtils intValueForPref:AKMaxHistoryPrefName];

    if ([currentHistoryItem isEqual:newHistoryItem])
    {
        return;
    }

    // Trim history beyond our max memory.
    while ((int)[_windowHistory count] > maxHistory - 1)
    {
        [_windowHistory removeObjectAtIndex:0];
        if (_windowHistoryIndex >= 0)
        {
            _windowHistoryIndex--;
        }
    }

    // Trim history items ahead of where the current one is.
    // Remember -count returns an *unsigned* int!
    if (_windowHistoryIndex >= 0)
    {
        while ((int)[_windowHistory count] > _windowHistoryIndex + 1)
        {
            [_windowHistory removeLastObject];
        }
    }

    // Add the current navigation state to the navigation history.
    [_windowHistory addObject:newHistoryItem];
    _windowHistoryIndex = [_windowHistory count] - 1;
    DIGSLogDebug(
        @"added history item [%@][%@][%@] at index %d",
        [[newHistoryItem topicToDisplay] pathInTopicBrowser],
        [newHistoryItem subtopicName],
        [newHistoryItem docName],
        _windowHistoryIndex);

    // Any time the history changes, we want to do the following UI updates.
    [self _refreshNavigationButtons];
    [[_topicBrowser window]
        setTitle:[newHistoryItem stringToDisplayInLists]];
}

- (AKTopic *)_currentTopic
{
    return [[self currentHistoryItem] topicToDisplay];
}

- (float)_computeBrowserFraction
{
    float browserHeight = [_topicBrowser frame].size.height;

    if (browserHeight == 0.0)
    {
        return 0.0;
    }
    else
    {
        float splitViewHeight =
            [_topLevelSplitView frame].size.height
            - [_topLevelSplitView dividerThickness];

        return browserHeight / splitViewHeight;
    }
}

- (float)_computeBrowserHeight
{
    float splitViewHeight =
        [_topLevelSplitView frame].size.height
        - [_topLevelSplitView dividerThickness];

    return _browserFractionWhenVisible * splitViewHeight;
}

- (void)_rememberCurrentTextSelection
{
// [agl] fill this in -- put text selection in history dictionary
}

@end
