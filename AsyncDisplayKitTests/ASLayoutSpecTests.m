//
//  ASLayoutSpecTests.m
//  AsyncDisplayKit
//
//  Copyright (c) 2014-present, Facebook, Inc.  All rights reserved.
//  This source code is licensed under the BSD-style license found in the
//  LICENSE file in the root directory of this source tree. An additional grant
//  of patent rights can be found in the PATENTS file in the same directory.
//

#import <XCTest/XCTest.h>

#import <AsyncDisplayKit/AsyncDisplayKit.h>

#pragma mark - ASDKExtendedLayoutSpec

/*
 * Extend the ASLayoutableStyle
 * It adds a
 *  - primitive / CGFloat (extendedWidth)
 *  - struct / ASDimension (extendedDimension)
 *  - primitive / ASStackLayoutDirection (extendedDirection)
 */
@protocol ASDKExtendedLayoutable <NSObject>
@property (assign, nonatomic) CGFloat extendedWidth;
@property (assign, nonatomic) ASDimension extendedDimension;
@property (copy, nonatomic) NSString *extendedName;
@end

/*
 * Let the ASLayoutableStyle conform to the MSLayoutable protocol and add properties implementation
 */
@interface ASLayoutableStyle (ASDKExtendedLayoutable) <ASDKExtendedLayoutable>
@end

@implementation ASLayoutableStyle (ASDKExtendedLayoutable)
ASDK_STYLE_PROP_PRIM(CGFloat, extendedWidth, setExtendedWidth, 0);
ASDK_STYLE_PROP_STR(ASDimension, extendedDimension, setExtendedDimension, ASDimensionMake(ASDimensionUnitAuto, 0));
ASDK_STYLE_PROP_OBJ(NSString *, extendedName, setExtendedName);
@end

/*
 * As the ASLayoutableStyle conforms to the ASDKExtendedLayoutable protocol now, ASDKExtendedLayoutable properties
 * can be accessed in ASDKExtendedLayoutSpec
 */
@interface ASDKExtendedLayoutSpec : ASLayoutSpec
@end

@implementation ASDKExtendedLayoutSpec

- (void)doSetSomeStyleValuesToChildren
{
  for (id<ASLayoutable> child in self.children) {
    child.style.extendedWidth = 100;
    child.style.extendedDimension = ASDimensionMake(100);
    child.style.extendedName = @"ASDK";
  }
}

- (void)doUseSomeStyleValuesFromChildren
{
  for (id<ASLayoutable> child in self.children) {
    __unused CGFloat extendedWidht = child.style.extendedWidth;
    __unused ASDimension extendedDimension = child.style.extendedDimension;
    __unused NSString *extendedName = child.style.extendedName;
  }
}

@end


#pragma mark - ASLayoutSpecTests

@interface ASLayoutSpecTests : XCTestCase

@end

@implementation ASLayoutSpecTests

- (void)testSetPrimitiveToExtendedStyle
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.style.extendedWidth = 100;
  XCTAssert(node.style.extendedWidth == 100, @"Primitive value should be set on extended style");
}

- (void)testSetStructToExtendedStyle
{
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.style.extendedDimension = ASDimensionMake(100);
  XCTAssertTrue(ASDimensionEqualToDimension(node.style.extendedDimension, ASDimensionMake(100)), @"Struct should be set on extended style");
}

- (void)testSetObjectToExtendedStyle
{
  NSString *extendedName = @"ASDK";
  
  ASDisplayNode *node = [[ASDisplayNode alloc] init];
  node.style.extendedName = extendedName;
  XCTAssertEqualObjects(node.style.extendedName, extendedName, @"Object should be set on extended style");
}


- (void)testUseOfExtendedStyleProperties
{
  ASDKExtendedLayoutSpec *extendedLayoutSpec = [ASDKExtendedLayoutSpec new];
  extendedLayoutSpec.children = @[[[ASDisplayNode alloc] init], [[ASDisplayNode alloc] init]];
  XCTAssertNoThrow([extendedLayoutSpec doSetSomeStyleValuesToChildren]);
  XCTAssertNoThrow([extendedLayoutSpec doUseSomeStyleValuesFromChildren]);
}

@end
