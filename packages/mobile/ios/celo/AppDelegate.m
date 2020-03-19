/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "AppDelegate.h"

#import <React/RCTBridge.h>
#import <React/RCTBundleURLProvider.h>
#import <React/RCTRootView.h>
#import <React/RCTLinkingManager.h>

@import Firebase;
#import "RNFirebaseNotifications.h"
#import "RNFirebaseMessaging.h"
#import "RNFirebaseLinks.h"

#import "RNSplashScreen.h"
#import "ReactNativeConfig.h"

// Use same key as react-native-secure-key-store
// so we don't reset already working installs
static NSString * const kHasRunBeforeKey = @"RnSksIsAppInstalled";

@interface AppDelegate ()

@property (nonatomic, weak) UIView *blurView;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  // Reset keychain on first run to clear existing Firebase credentials
  // Note: react-native-secure-key-store also does that but is run too late
  // and hence can't clear Firebase credentials
  [self resetKeychainIfNecessary];
  NSString *env = [ReactNativeConfig envFor:@"FIREBASE_ENABLED"];
  if (env.boolValue) {
    [FIROptions defaultOptions].deepLinkURLScheme = @"celo";
    [FIRApp configure];
  }
  [RNFirebaseNotifications configure];
  RCTBridge *bridge = [[RCTBridge alloc] initWithDelegate:self launchOptions:launchOptions];
  RCTRootView *rootView = [[RCTRootView alloc] initWithBridge:bridge
                                                   moduleName:@"celo"
                                            initialProperties:nil];
  
  [RNSplashScreen showSplash:@"LaunchScreen" inRootView:rootView];
  rootView.backgroundColor = [[UIColor alloc] initWithRed:1.0f green:1.0f blue:1.0f alpha:1];
  
  self.window = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
  UIViewController *rootViewController = [UIViewController new];
  rootViewController.view = rootView;
  self.window.rootViewController = rootViewController;
  [self.window makeKeyAndVisible];
  return YES;
}

- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge
{
#if DEBUG
  return [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index" fallbackResource:nil];
#else
  return [[NSBundle mainBundle] URLForResource:@"main" withExtension:@"jsbundle"];
#endif
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification {
  [[RNFirebaseNotifications instance] didReceiveLocalNotification:notification];
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(nonnull NSDictionary *)userInfo
fetchCompletionHandler:(nonnull void (^)(UIBackgroundFetchResult))completionHandler{
  [[RNFirebaseNotifications instance] didReceiveRemoteNotification:userInfo fetchCompletionHandler:completionHandler];
}

- (void)application:(UIApplication *)application didRegisterUserNotificationSettings:(UIUserNotificationSettings *)notificationSettings {
  [[RNFirebaseMessaging instance] didRegisterUserNotificationSettings:notificationSettings];
}

// Reset keychain on first app run, this is so we don't run with leftover items
// after reinstalling the app
- (void)resetKeychainIfNecessary
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  if ([defaults boolForKey:kHasRunBeforeKey]) {
    return;
  }
  
  NSArray *secItemClasses = @[(__bridge id)kSecClassGenericPassword,
                              (__bridge id)kSecAttrGeneric,
                              (__bridge id)kSecAttrAccount,
                              (__bridge id)kSecClassKey,
                              (__bridge id)kSecAttrService];
  for (id secItemClass in secItemClasses) {
    NSDictionary *spec = @{(__bridge id)kSecClass:secItemClass};
    SecItemDelete((__bridge CFDictionaryRef)spec);
  }
  
  [defaults setBool:YES forKey:kHasRunBeforeKey];
  [defaults synchronize];
}


- (BOOL)application:(UIApplication *)application
            openURL:(NSURL *)url
            options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
  BOOL handled = [RCTLinkingManager application:application openURL:url options:options];
  
  if (!handled) {
    handled = [[RNFirebaseLinks instance] application:application openURL:url options:options];
  }
  
  return handled;
}

- (BOOL)application:(UIApplication *)application
continueUserActivity:(NSUserActivity *)userActivity
 restorationHandler:(void (^)(NSArray *))restorationHandler {
  return [[RNFirebaseLinks instance] application:application continueUserActivity:userActivity restorationHandler:restorationHandler];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
  // Prevent sensitive information from appearing in the task switcher
  // See https://developer.apple.com/library/archive/qa/qa1838/_index.html
  
  if (self.blurView) {
    // Shouldn't happen ;)
    return;
  }
  
  UIVisualEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
  UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
  blurView.frame = self.window.bounds;
  self.blurView = blurView;
  [self.window addSubview:blurView];
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
  // Remove our blur
  [self.blurView removeFromSuperview];
  self.blurView = nil;
}

@end
