//
//  ASDKPerf.m
//  Sample
//
//  Created by Michael Schneider on 7/9/16.
//  Copyright © 2016 Facebook. All rights reserved.
//

#import "ASDKPerf.h"
#import "FBAnimationPerformanceTracker.h"
#import <objc/runtime.h>

@interface UIScrollView (SecondaryDelegate)

@property (nonatomic, weak) id<UIScrollViewDelegate> secondaryDelegate;

@end

@interface ASDKPerfDelegateProxy : NSProxy <UIScrollViewDelegate>
@property (nonatomic, weak) id<UIScrollViewDelegate> primaryDelegate;
@property (nonatomic, weak) id<UIScrollViewDelegate> secondaryDelegate;
@end

@implementation ASDKPerfDelegateProxy

- (BOOL)respondsToSelector:(SEL)selector
{
  return [_primaryDelegate respondsToSelector:selector] ||  [_secondaryDelegate respondsToSelector:selector];
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector
{
  NSObject *delegateForResonse = [_primaryDelegate respondsToSelector:selector] ? _primaryDelegate : _secondaryDelegate;
  return [delegateForResonse respondsToSelector:selector] ? [delegateForResonse methodSignatureForSelector:selector] : nil;
}

- (void)forwardInvocation:(NSInvocation *)invocation
{
  [self invokeInvocation:invocation onDelegate:_primaryDelegate];
  [self invokeInvocation:invocation onDelegate:_secondaryDelegate];
}

- (void)invokeInvocation:(NSInvocation *)invocation onDelegate:(id<UIScrollViewDelegate>)delegate
{
  if ([delegate respondsToSelector:invocation.selector]) {
    [invocation invokeWithTarget:delegate];
  }
}

@end

// 1. Private interface extension
@interface UIScrollView ()
@property (nonatomic, strong) ASDKPerfDelegateProxy *delegateProxy;
@end

@implementation UIScrollView (SecondaryDelegate)

// 2. Setter
- (void)setSecondaryDelegate:(id<UIScrollViewDelegate>)secondaryDelegate
{
  if (!self.delegateProxy) {
    self.delegateProxy = [ASDKPerfDelegateProxy alloc];
    self.delegateProxy.primaryDelegate = self.delegate;
  }

  self.delegateProxy.secondaryDelegate = secondaryDelegate;
  self.delegate = self.delegateProxy;
}

// 3. Getter
- (id<UIScrollViewDelegate>)secondaryDelegate
{
  return self.delegateProxy.secondaryDelegate;
}

// 4. Associated object
- (void)setDelegateProxy:(ASDKPerfDelegateProxy *)delegateProxy
{
  objc_setAssociatedObject(self, @selector(delegateProxy), delegateProxy, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (ASDKPerfDelegateProxy *)delegateProxy
{
  return objc_getAssociatedObject(self, @selector(delegateProxy));
}

@end

@interface FBAnimationPerformanceTrackerDelegateImpl : NSObject<FBAnimationPerformanceTrackerDelegate>


@end

@implementation FBAnimationPerformanceTrackerDelegateImpl

#pragma mark - FBAnimationPerformanceTrackerDelegate

- (void)reportDurationInMS:(NSInteger)duration smallDropEvent:(double)smallDropEvent largeDropEvent:(double)largeDropEvent
{
  static NSInteger durationSum = 0;
  static double smallDropEventSum = 0;
  static double largeDropEventSum = 0;
  
  durationSum += duration;
  smallDropEventSum += smallDropEvent;
  largeDropEventSum += largeDropEvent;
  
  double small = durationSum / smallDropEventSum;
  double large = durationSum / largeDropEventSum;
  double smallPercentage = 1 - (1 / small);
  double largePercentage = 1 - (1 / large);
  
  NSAttributedString *attributedString = [[NSAttributedString alloc] initWithString:
                                          [NSString stringWithFormat:@"small %.1f, %.5f%%, large: %.1f, %.5f%%", small, smallPercentage, large, largePercentage]];
  NSLog(@"%@", attributedString.string);
}

- (void)reportStackTrace:(NSString *)stack withSlide:(NSString *)slide
{
  NSLog(@"Stack Trace: %@", stack);
  NSLog(@"Slide: %@", slide);
}

@end


@interface ASDKPerf () <UIScrollViewDelegate>

@end


// TODO:
// - Move to Class Methods
// - Better way to handle perf delegates
// - Better way to get measurements
// - Better way to track components / nodes that are slow -> add register nodes

@implementation ASDKPerf {
  //FBAnimationPerformanceTracker *_perfTracker;
  NSMapTable<UIScrollView *, FBAnimationPerformanceTracker *> *_perfTrackers;
  NSMutableArray *_perfDelegates;
  //NSArray *_perfTrackersStrong;
}

- (instancetype)init
{
  self = [super init];
  if (self) {
    _perfTrackers = [NSMapTable weakToStrongObjectsMapTable];
    _perfDelegates = [NSMutableArray new];
  }
  return self;
}

- (void)registerScrollView:(UIScrollView *)scrollView
{
  FBAnimationPerformanceTracker *perfTracker = [[FBAnimationPerformanceTracker alloc] initWithConfig:[FBAnimationPerformanceTracker standardConfig]];
  FBAnimationPerformanceTrackerDelegateImpl *delegate = [FBAnimationPerformanceTrackerDelegateImpl new];
  perfTracker.delegate = delegate;
  [_perfDelegates addObject:delegate];
  [_perfTrackers setObject:perfTracker forKey:scrollView];
  scrollView.secondaryDelegate = self;
}

- (void)deregesiterScrollViewWithIdentifier:(NSString *)identifier
{
  
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  [[_perfTrackers objectForKey:scrollView] start];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
  if (scrollView.dragging == NO) {
    [[_perfTrackers objectForKey:scrollView] stop];
  }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
  if (decelerate == NO) {
    [[_perfTrackers objectForKey:scrollView] stop];
  }
}

@end
