#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>

@interface PairDeviceViewController : UIViewController<UITableViewDelegate, UITableViewDataSource, CBCentralManagerDelegate, CBPeripheralDelegate>

@end
