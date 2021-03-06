/*
 * AKParser.m
 *
 * Created by Andy Lee on Sat Mar 06 2004.
 * Copyright (c) 2003, 2004 Andy Lee. All rights reserved.
 */

#import "AKParser.h"

#import "DIGSLog.h"
#import "AKDatabase.h"

@implementation AKParser

@synthesize targetDatabase = _targetDatabase;
@synthesize targetFrameworkName = _targetFrameworkName;

#pragma mark -
#pragma mark Class methods

+ (void)recursivelyParseDirectory:(NSString *)dirPath
                      forDatabase:(AKDatabase *)database
                    frameworkName:(NSString *)frameworkName
{
    if (![[NSFileManager defaultManager] fileExistsAtPath:dirPath])
    {
        return;
    }

    AKParser *parser = [[[self alloc] initWithDatabase:database
                                         frameworkName:frameworkName] autorelease];
    [parser processDirectory:dirPath recursively:YES];
}

+ (void)parseFilesInSubpaths:(NSArray *)subpaths
                underBaseDir:(NSString *)baseDir
                 forDatabase:(AKDatabase *)database
               frameworkName:(NSString *)frameworkName
{
    for (NSString *subpath in subpaths)
    {
        NSString *fullPath = [baseDir stringByAppendingPathComponent:subpath];
        AKParser *parser = [[[self alloc] initWithDatabase:database
                                             frameworkName:frameworkName] autorelease];
        [parser processFile:fullPath];
    }
}

#pragma mark -
#pragma mark Init/awake/dealloc

- (id)initWithDatabase:(AKDatabase *)database frameworkName:(NSString *)frameworkName
{
    if ((self = [super init]))
    {
        _targetDatabase = [database retain];
        _targetFrameworkName = [frameworkName copy];
    }

    return self;
}

- (id)init
{
    DIGSLogError_NondesignatedInitializer();
    return nil;
}

- (void)dealloc
{
    [_targetDatabase release];
    [_targetFrameworkName release];

    [super dealloc];
}

#pragma mark -
#pragma mark Parsing

- (NSMutableData *)loadDataToBeParsed
{
    return [NSMutableData dataWithContentsOfFile:[self currentPath]];
}

- (void)parseCurrentFile
{
    DIGSLogError_MissingOverride();
}

#pragma mark -
#pragma mark DIGSFileProcessor methods

// Sets things up for -parseCurrentFile to do the real work.
- (void)processCurrentFile
{
    // Set up.
    NSMutableData *fileContents = [[self loadDataToBeParsed] retain];

    if (fileContents)
    {
        _dataStart = [fileContents bytes];
        _current = _dataStart;
        _dataEnd = _dataStart + [fileContents length];
    }
    else
    {
        _dataStart = NULL;
        _current = NULL;
        _dataEnd = NULL;
    }

    // Do the job.
    [self parseCurrentFile];

    // Clean up.
    _dataStart = NULL;
    _current = NULL;
    _dataEnd = NULL;
    [fileContents release];
}

@end
