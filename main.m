//
//  main.m
//  CoordinationDeadlock
//
//  Created by Friedrich Gräter on 05.03.14.
//  Copyright (c) 2014 Friedrich Gräter. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SomePresenter : NSObject <NSFilePresenter>
{
	NSURL				*_URL;
	NSOperationQueue	*_queue;
}

- (id)initWithURL:(NSURL *)URL;

@end

@implementation SomePresenter

- (id)initWithURL:(NSURL *)URL
{
	self = [super init];
	
	if (self) {
		_URL = URL;
		_queue = [NSOperationQueue new];
		_queue.maxConcurrentOperationCount = 1;
		
		[NSFileCoordinator addFilePresenter: self];
	}
	
	return self;
}

- (NSURL *)presentedItemURL
{
	return _URL;
}

- (NSOperationQueue *)presentedItemOperationQueue
{
	return _queue;
}

- (void)presentedItemDidChange
{
	NSLog(@"Will read: %@", _URL);
	
	// Deadlock occurs, since both presenters are waiting for the callback of -relinquishPresentedItemToReader of the respective other presenter, which are enqueued after the -presentedItemDidChange.
	[[[NSFileCoordinator alloc] initWithFilePresenter:self] coordinateReadingItemAtURL:_URL options:NSFileCoordinatorReadingWithoutChanges error:NULL byAccessor:^(NSURL *newURL) {
		NSLog(@"Change presented: %@", newURL);
	}];
	
	NSLog(@"Completed.");
}

- (void)relinquishPresentedItemToReader:(void (^)(void (^)(void)))reader
{
	// Will never be called, since -presentedItemDidChange is blocking the queue...
	NSLog(@"Relinquish read...");
	reader(^{ NSLog(@"Relinquished reader"); });
}

@end

int main(int argc, const char * argv[])
{
	// Setup presenters
	NSURL *tempURL = [[NSURL fileURLWithPath: @"test.txt"] URLByStandardizingPath];
	[@"xy" writeToURL:tempURL atomically:YES encoding:NSUTF8StringEncoding error:NULL];
	
	SomePresenter *presenterA = [[SomePresenter alloc] initWithURL: tempURL];
	SomePresenter *presenterB = [[SomePresenter alloc] initWithURL: tempURL];
	
	// Generate a -presentedItemDidChange in both presenters by writing the file
	[[[NSFileCoordinator alloc] initWithFilePresenter: nil] coordinateWritingItemAtURL:tempURL options:0 error:NULL byAccessor:^(NSURL *newURL) {
		[@"abc" writeToURL:newURL atomically:NO encoding:NSUTF8StringEncoding error:NULL];
	}];
	
	// Wait some seconds for -presentedItemDidChange notifications to be enqueued
	[NSThread sleepForTimeInterval: 2];
	
	// Wait until operations have been completed
	NSLog(@"Wait for completion:");
	
	[presenterA.presentedItemOperationQueue waitUntilAllOperationsAreFinished];
	[presenterB.presentedItemOperationQueue waitUntilAllOperationsAreFinished];
	
	// Never reached...
	NSLog(@"Done.");
}

