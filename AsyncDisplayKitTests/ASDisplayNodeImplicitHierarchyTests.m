//
//  ASDisplayNodeImplicitHierarchyTests.m
//  AsyncDisplayKit
//
//  Created by Levi McCallum on 2/1/16.
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>

#import "ASDisplayNode.h"
#import "ASDisplayNode+Beta.h"
#import "ASDisplayNode+Subclasses.h"

#import "ASStaticLayoutSpec.h"
#import "ASStackLayoutSpec.h"

@interface ASSpecTestDisplayNode : ASDisplayNode

/**
 Simple state identifier to allow control of current spec inside of the layoutSpecBlock
 */
@property (strong, nonatomic) NSNumber *layoutState;

@end

@implementation ASSpecTestDisplayNode

- (instancetype)init
{
  self = [super init];
  if (self) {
    _layoutState = @1;
  }
  return self;
}

@end

@interface ASDisplayNodeImplicitHierarchyTests : XCTestCase

@end

@implementation ASDisplayNodeImplicitHierarchyTests

- (void)testFeatureFlag
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  XCTAssertFalse(node.automaticallyManagesSubnodes);
  
  node.automaticallyManagesSubnodes = YES;
  XCTAssertTrue(node.automaticallyManagesSubnodes);
}

- (void)testInitialNodeInsertionWithOrdering
{
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node3 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node4 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node5 = [[ASDisplayNode alloc] init];

  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  node.layoutSpecBlock = ^(ASDisplayNode *weakNode, ASSizeRange constrainedSize) {
    ASStaticLayoutSpec *staticLayout = [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node4]];
    
    ASStackLayoutSpec *stack1 = [[ASStackLayoutSpec alloc] init];
    [stack1 setChildren:@[node1, node2]];

    ASStackLayoutSpec *stack2 = [[ASStackLayoutSpec alloc] init];
    [stack2 setChildren:@[node3, staticLayout]];
    
    return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[stack1, stack2, node5]];
  };
  
  // Create a pending layout
  [node measureWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeZero)];
  
  // Set some size so the layout is actually happening
  CGRect r = node.frame;
  r.size = CGSizeMake(100, 100);
  node.frame = r;
  
  // Create so the layout call is actually happening
  [node view];
  [node layoutIfNeeded];
  
  XCTAssertEqual(node.subnodes[0], node5);
  XCTAssertEqual(node.subnodes[1], node1);
  XCTAssertEqual(node.subnodes[2], node2);
  XCTAssertEqual(node.subnodes[3], node3);
  XCTAssertEqual(node.subnodes[4], node4);
}

- (void)testCalculatedLayoutHierarchyTransitions
{
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node3 = [[ASDisplayNode alloc] init];
  
  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  node.layoutSpecBlock = ^(ASDisplayNode *weakNode, ASSizeRange constrainedSize){
    ASSpecTestDisplayNode *strongNode = (ASSpecTestDisplayNode *)weakNode;
    if ([strongNode.layoutState isEqualToNumber:@1]) {
      return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node1, node2]];
    } else {
      ASStackLayoutSpec *stackLayout = [[ASStackLayoutSpec alloc] init];
      [stackLayout setChildren:@[node3, node2]];
      return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node1, stackLayout]];
    }
  };
  
  // Create a pending layout
  [node measureWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeZero)];
  
  // Set some size so the layout is actually happening
  CGRect r = node.frame;
  r.size = CGSizeMake(100, 100);
  node.frame = r;
  
  // Create so the layout call is actually happening
  [node view];
  [node layoutIfNeeded];
  
  XCTAssertEqual(node.subnodes[0], node1);
  XCTAssertEqual(node.subnodes[1], node2);
  
  node.layoutState = @2;
  [node setNeedsLayout];
  [node layoutIfNeeded];

  XCTAssertEqual(node.subnodes[0], node1);
  XCTAssertEqual(node.subnodes[1], node3);
  XCTAssertEqual(node.subnodes[2], node2);
}

- (void)testLayoutTransitionMeasurementCompletionBlockIsCalledOnMainThread
{
  ASDisplayNode *displayNode = [ASDisplayNode new];
  
  // Trigger explicit view creation to be able to use the Transition API
  [displayNode view];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Call measurement completion block on main"];
  
  [displayNode transitionLayoutWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeZero) animated:YES measurementCompletion:^{
    XCTAssertTrue(ASDisplayNodeThreadIsMain(), @"Measurement completion block should be called on main thread");
    [expectation fulfill];
  }];
  
  [self waitForExpectationsWithTimeout:2.0 handler:nil];
}

- (void)testMeasurementInBackgroundThreadWithLoadedNode
{
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  
  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  node.layoutSpecBlock = ^(ASDisplayNode *weakNode, ASSizeRange constrainedSize) {
    ASSpecTestDisplayNode *strongNode = (ASSpecTestDisplayNode *)weakNode;
    if ([strongNode.layoutState isEqualToNumber:@1]) {
      return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node1]];
    } else {
      return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node2]];
    }
  };
  
  // Intentionally trigger view creation
  [node2 view];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Fix IHM layout also if one node is already loaded"];
  
  dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    
    [node measureWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeZero)];
    XCTAssertEqual(node.subnodes[0], node1);
    
    node.layoutState = @2;
    [node invalidateCalculatedLayout];
    [node measureWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeZero)];
    
    // Dispatch back to the main thread to let the insertion / deletion of subnodes happening
    dispatch_async(dispatch_get_main_queue(), ^{
      XCTAssertEqual(node.subnodes[0], node2);
      [expectation fulfill];
    });
  });
  
  [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
    if (error) {
      NSLog(@"Timeout Error: %@", error);
    }
  }];
}

- (void)testTransitionLayoutWithAnimationWithLoadedNodes
{
  ASDisplayNode *node1 = [[ASDisplayNode alloc] init];
  ASDisplayNode *node2 = [[ASDisplayNode alloc] init];
  
  ASSpecTestDisplayNode *node = [[ASSpecTestDisplayNode alloc] init];
  node.automaticallyManagesSubnodes = YES;
  
  node.layoutSpecBlock = ^(ASDisplayNode *weakNode, ASSizeRange constrainedSize) {
    ASSpecTestDisplayNode *strongNode = (ASSpecTestDisplayNode *)weakNode;
    if ([strongNode.layoutState isEqualToNumber:@1]) {
      return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node1]];
    } else {
      return [ASStaticLayoutSpec staticLayoutSpecWithChildren:@[node2]];
    }
  };
 
  // Intentionally trigger view creation
  [node view];
  [node1 view];
  [node2 view];
  
  XCTestExpectation *expectation = [self expectationWithDescription:@"Fix IHM layout transition also if one node is already loaded"];
  
  [node measureWithSizeRange:ASSizeRangeMake(CGSizeZero, CGSizeZero)];
  XCTAssertEqual(node.subnodes[0], node1);
  
  node.layoutState = @2;
  [node invalidateCalculatedLayout];
  [node transitionLayoutAnimated:YES measurementCompletion:^{
    // Push this to the next runloop to let async insertion / removing of nodes finished before checking
    dispatch_async(dispatch_get_main_queue(), ^{
      XCTAssertEqual(node.subnodes[0], node2);
      [expectation fulfill];
    });
  }];
  
  [self waitForExpectationsWithTimeout:5.0 handler:^(NSError *error) {
    if (error) {
      NSLog(@"Timeout Error: %@", error);
    }
  }];
}

@end
