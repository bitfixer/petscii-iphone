#import "PairDeviceViewController.h"
#import "AppDelegate.h"

@interface PairDeviceViewController ()
@end

@implementation PairDeviceViewController
{
    UIButton *_searchButton;
    UILabel *_statusLabel;
    
    UIView *_spinnerBackView;
    UIActivityIndicatorView *_spinner;
    UITableView *_tableView;
    
    NSMutableArray *_peripherals;
}

- (void) viewDidLoad
{
    self.view.backgroundColor = [UIColor grayColor];
    
    // create search for bluetooth button
    _searchButton = [[UIButton buttonWithType:UIButtonTypeRoundedRect] retain];
    [_searchButton setTitle:@"Refresh" forState:UIControlStateNormal];
    _searchButton.titleLabel.textColor = [UIColor blackColor];
    _searchButton.backgroundColor = [UIColor whiteColor];
    _searchButton.frame = CGRectMake(0, 0, 100, 40);
    _searchButton.center = CGPointMake(self.view.frame.size.width/2.0, self.view.frame.size.height - 80);
    [self.view addSubview:_searchButton];
    
    _statusLabel = [[UILabel alloc] init];
    
    _tableView = [[UITableView alloc] init];
    _tableView.frame = CGRectMake(0, 100, self.view.frame.size.width, self.view.frame.size.height-200);
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.alpha = 1.0;
    [self.view addSubview:_tableView];
    
    _spinnerBackView = [[UIView alloc] init];
    _spinnerBackView.frame = CGRectMake(0, 0, 80, 80);
    _spinnerBackView.backgroundColor = [UIColor blackColor];
    _spinnerBackView.alpha = 0.5;
    _spinnerBackView.center = self.view.center;
    [self.view addSubview:_spinnerBackView];
    [_spinnerBackView.layer setCornerRadius:10.0];
    
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    _spinner.center = CGPointMake(_spinnerBackView.frame.size.width/2.0, _spinnerBackView.frame.size.height/2.0);
    [_spinnerBackView addSubview:_spinner];
    
    [_peripherals release];
    _peripherals = [[NSMutableArray alloc] init];
}

- (void)dealloc
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.bluetoothCentralManager.delegate = appDelegate;
    [_searchButton release]; _searchButton = nil;
    [_statusLabel release]; _statusLabel = nil;
    [_spinner release]; _spinner = nil;
    [_tableView release]; _tableView = nil;
    [_peripherals release]; _peripherals = nil;
    
    [super dealloc];
}

- (void)viewDidAppear:(BOOL)animated
{
    _spinnerBackView.hidden = NO;
    [_spinner startAnimating];
    
    //[self performSelector:@selector(loadDevices) withObject:nil afterDelay:1.0];
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.bluetoothCentralManager.delegate = self;
    if (appDelegate.peripheral)
    {
        [appDelegate.bluetoothCentralManager cancelPeripheralConnection:appDelegate.peripheral];
        appDelegate.peripheral = nil;
    }
    
    [_peripherals release];
    _peripherals = [[NSMutableArray alloc] init];
    [appDelegate.bluetoothCentralManager scanForPeripheralsWithServices:Nil options:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    [appDelegate.bluetoothCentralManager stopScan];
}

- (void)loadDevices
{
    _spinner.hidden = YES;
    [UIView animateWithDuration:0.5 animations:^{
        _tableView.alpha = 1.0;
    }];
}

#pragma mark
#pragma UITableViewDatasource methods
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CBPeripheral *peripheral = [_peripherals objectAtIndex:indexPath.row];
    
    UITableViewCell *tableViewCell = [[[UITableViewCell alloc] init] autorelease];
    UILabel *label = [[[UILabel alloc] init] autorelease];
    label.frame = CGRectMake(0, 0, 100, 20);
    //label.text = [NSString stringWithFormat:@" #%d",indexPath.row];
    label.text = peripheral.name;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor blackColor];
    [tableViewCell addSubview:label];
    
    /*
     NSString *key = [NSString stringWithFormat:@"dot_%d",indexPath.row];
     NSNumber *cellConnectedNumbers = [[NSUserDefaults standardUserDefaults] objectForKey:key];
     BOOL connected = NO;
     if (cellConnectedNumbers)
     {
     connected = [cellConnectedNumbers boolValue];
     }
     
     NSString *connectedText = @"not connected";
     if (connected)
     {
     connectedText = @"connected";
     }
     */
    NSString *connectedText = @"test";
    
    UILabel *connectedLabel = [[[UILabel alloc] init] autorelease];
    connectedLabel.frame = CGRectMake(150,0,150,20);
    connectedLabel.text = connectedText;
    connectedLabel.backgroundColor = [UIColor clearColor];
    connectedLabel.textColor = [UIColor blackColor];
    [tableViewCell addSubview:connectedLabel];
    
    return tableViewCell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_peripherals count];
}

#pragma mark
#pragma UITableViewDelegate methods
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 50;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    /*
     NSString *key = [NSString stringWithFormat:@"dot_%d",indexPath.row];
     NSNumber *cellConnectedNumbers = [[NSUserDefaults standardUserDefaults] objectForKey:key];
     BOOL connected = NO;
     if (cellConnectedNumbers)
     {
     connected = [cellConnectedNumbers boolValue];
     }
     
     connected = !connected;
     cellConnectedNumbers = [NSNumber numberWithBool:connected];
     [[NSUserDefaults standardUserDefaults] setObject:cellConnectedNumbers forKey:key];
     
     [tableView deselectRowAtIndexPath:indexPath animated:YES];
     [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
     withRowAnimation:UITableViewRowAnimationAutomatic];
     
     NSArray *connectedDevices = [[NSUserDefaults standardUserDefaults] objectForKey:@"connected_devices"];
     NSMutableArray *mConnectedDevices = [NSMutableArray arrayWithArray:connectedDevices];
     if (!mConnectedDevices)
     {
     mConnectedDevices = [NSMutableArray array];
     }
     if (connected)
     {
     // add this device
     [mConnectedDevices addObject:key];
     }
     else
     {
     // remove the device
     [mConnectedDevices removeObject:key];
     }
     
     [[NSUserDefaults standardUserDefaults] setObject:mConnectedDevices forKey:@"connected_devices"];
     
     NSLog(@"done");
     */
    
    [_spinner startAnimating];
    _spinnerBackView.hidden = NO;
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    CBPeripheral *peripheral = [_peripherals objectAtIndex:indexPath.row];
    [appDelegate.bluetoothCentralManager stopScan];
    [appDelegate.bluetoothCentralManager connectPeripheral:peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central
 didDiscoverPeripheral:(CBPeripheral *)peripheral
     advertisementData:(NSDictionary *)advertisementData
                  RSSI:(NSNumber *)RSSI
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_spinner stopAnimating];
        _spinnerBackView.hidden = YES;
    });
    
    NSLog(@"Discovered %@ %@ %@", peripheral.name, peripheral.identifier.UUIDString, advertisementData);
    [_peripherals addObject:peripheral];
    [_tableView reloadData];
    
    
    //[appDelegate.bluetoothCentralManager stopScan];
    //appDelegate.peripheral = peripheral;
    //[appDelegate.bluetoothCentralManager connectPeripheral:appDelegate.peripheral options:nil];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [_spinner stopAnimating];
        _spinnerBackView.hidden = YES;
    });
    
    AppDelegate *appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    appDelegate.peripheral = peripheral;
    NSLog(@"connected to %@ %@", peripheral.name, peripheral.identifier.UUIDString);
    //peripheral.delegate = self;
    //[peripheral discoverServices:nil];
    
    //[self.navigationController popViewControllerAnimated:YES];
    [appDelegate beginCapture];
}

- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"central manager updated state");
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered service %@ %@", service, service.UUID);
        NSLog(@"Discovering characteristics for service %@", service);
        [peripheral discoverCharacteristics:nil forService:service];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral
didDiscoverCharacteristicsForService:(CBService *)service
             error:(NSError *)error
{
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"Discovered characteristic %@ %d", characteristic, characteristic.properties);
    }
}


@end
