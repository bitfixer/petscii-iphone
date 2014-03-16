//
//  AppDelegate.m
//  testcam
//
//  Created by Gubbish on 4/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "AppDelegate.h"

#import "ViewController.h"
#import "PairDeviceViewController.h"
//#import "PSGrabController.h"

@implementation AppDelegate
{
    CBCharacteristic *_writeCharacteristic;
    NSData *_sendData;
}

@synthesize window = _window;
@synthesize viewController = _viewController;
@synthesize bluetoothCentralManager = _bluetoothCentralManager;
@synthesize peripheral = _peripheral;

- (void)dealloc
{
    [_window release];
    [_viewController release];
    [_bluetoothCentralManager release]; _bluetoothCentralManager = nil;
    [_peripheral release]; _peripheral = nil;
    [_sendData release]; _sendData = nil;
    [super dealloc];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
    // Override point for customization after application launch.
    //self.viewController = (ViewController *)[[UIImagePickerController alloc] init];
    
    //self.viewController = [[[ViewController alloc] init] autorelease];
    //self.viewController = [[[PSGrabController alloc] init] autorelease];
    
    self.viewController = [[[PairDeviceViewController alloc] init] autorelease];
    
    self.window.rootViewController = self.viewController;
    [self.window makeKeyAndVisible];
    
    [_bluetoothCentralManager release];
    _bluetoothCentralManager = [[CBCentralManager alloc] initWithDelegate:self
                                                                    queue:nil
                                                                  options:nil];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
     */
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    /*
     Called when the application is about to terminate.
     Save data if appropriate.
     See also applicationDidEnterBackground:.
     */
}

- (void) beginCapture
{
    // get the write characteristic
    self.peripheral.delegate = self;
    [self.peripheral discoverServices:nil];
    
    //self.viewController = [[[ViewController alloc] init] autorelease];
    //self.window.rootViewController = self.viewController;
}

#pragma mark
#pragma CBPeripheralDelegate methods

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services)
    {
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)                    peripheral:(CBPeripheral *)peripheral
  didDiscoverCharacteristicsForService:(CBService *)service
                                 error:(NSError *)error
{
    for (CBCharacteristic *characteristic in service.characteristics)
    {
        //if (characteristic.properties == CBCharacteristicPropertyWrite)
        if (characteristic.properties == CBCharacteristicPropertyWriteWithoutResponse)
        {
            NSLog(@"WRITE");
            if (!_writeCharacteristic)
            {
                [_writeCharacteristic release];
                _writeCharacteristic = [characteristic retain];
                
                self.viewController = [[[ViewController alloc] init] autorelease];
                self.window.rootViewController = self.viewController;
            }
        }
    }
}

- (void) writeValueToPeripheral:(NSData *)data
{
    //[_sendData release]; _sendData = nil;
    //_sendData = [data retain];
    
    [self.peripheral writeValue:data
              forCharacteristic:_writeCharacteristic
                           type:CBCharacteristicWriteWithoutResponse];
    //[_sendData release]; _sendData = nil;
    //self.sendingData = YES;
}

- (void)                peripheral:(CBPeripheral *)peripheral
    didWriteValueForCharacteristic:(CBCharacteristic *)characteristic
                             error:(NSError *)error
{
    if (error)
    {
        NSLog(@"error writing: %@", [error localizedDescription]);
    }
    else
    {
        NSLog(@"successful write");
    }
    
    [_sendData release]; _sendData = nil;
    self.sendingData = NO;
}

#pragma mark
#pragma CBCentralManagerDelegate methods

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"central manager updated state");
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discovered peripheral!");
}

- (void)centralManager:(CBCentralManager *)central
didDisconnectPeripheral:(CBPeripheral *)peripheral
                 error:(NSError *)error
{
    NSLog(@"lost connection with peripheral");
    self.peripheral = nil;
    //[_nav popToRootViewControllerAnimated:YES];
}

@end
