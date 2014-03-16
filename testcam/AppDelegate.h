//
//  AppDelegate.h
//  testcam
//
//  Created by Gubbish on 4/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@class ViewController;

@interface AppDelegate : UIResponder <UIApplicationDelegate,CBCentralManagerDelegate,CBPeripheralDelegate>

- (void) beginCapture;
- (void) writeValueToPeripheral:(NSData *)data;

@property (retain, nonatomic) UIWindow *window;
@property (nonatomic, retain) CBCentralManager *bluetoothCentralManager;
@property (nonatomic, retain) CBPeripheral *peripheral;
@property (retain, nonatomic) UIViewController *viewController;

@property (nonatomic, assign) BOOL sendingData;

@end
