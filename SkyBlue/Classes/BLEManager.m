//
//  BLEManager.m
//  SkyBlue
//
//  Created by Enix Yu on 30/5/2018.
//  Copyright © 2018 LinkJob. All rights reserved.
//

#import "BLEManager.h"
#import "BLEPeripheral.h"

#define BLE_MTU                             20

#define weakify(self)                       __weak typeof((self)) weak##self = (self);

#define strongify(self)                     __strong typeof((weak##self)) strong##self = weak##self;

static NSString * const ErrorDomain = @"SkyBlue.ErrorDomain";

NSString *BLENotificationDisconnected = @"SkyBlue.disconnected";

NSString *BLENotificationScanStopped = @"SkyBlue.scanStopped";


@interface BLEManager () <CBPeripheralDelegate, CBCentralManagerDelegate>

@property (nonatomic, strong) CBCentralManager *manager;

/**
 * The discoverred ble peripheral list
 */
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSUUID *, BLEPeripheral *> *discoverredPeripherals;

/**
 * The connected ble peripheral list
 */
@property (nonatomic, strong, readwrite) NSMutableDictionary<NSUUID *, BLEPeripheral *> *connectedPeripherals;

/**
 * The notification callbacks for the subscribed characteristics
 */
@property (nonatomic, strong) NSMutableDictionary<NSString *, ValueUpdateCallback> *notificationCallbacks;

/**
 * The service UUID list for peripheral scan. If nil, then peripheral scan will not filter by the service UUID.
 */
@property (nonatomic, strong) NSArray<NSString *> *scanUUIDs;

/**
 * The timeout timer for connect peripheral
 */
@property (nonatomic, strong) NSTimer *connectTimer;

/**
 * The timeout timer for peripheral enumeration
 */
@property (nonatomic, strong) NSTimer *enumerateTimer;

/**
 * The timer to detect write timeout for write with response operation
 */
@property (nonatomic, strong) NSTimer *sendTimer;

/**
 * Scan peripheral timer
 */
@property (nonatomic, strong) NSTimer *scanTimer;

/**
 * The callback for peripheral enumeration result
 */
@property (nonatomic, strong) ConnectCallback enumerateCompletion;

/**
 * The enumerated peripheral service list
 */
@property (nonatomic, strong) NSMutableDictionary<CBUUID *, NSNumber *> *enumeratedServices;

/**
 * The callback for connect peripheral result
 */
@property (nonatomic, strong) ConnectCallback connectCompletion;

/**
 * The result callback for writing data to characteristic
 */
@property (nonatomic, strong) WriteResultCallback writeCompletion;

/**
 * The result callback for peripheral scan
 */
@property (nonatomic, strong) ScanCallback scanCallback;

/**
 * The result callback for peripheral disconnect operation
 */
@property (nonatomic, strong) DisconnectCallback disconnectCallback;

/**
 * Whether BLE module is enable or not. If not, then scan/connect will not be performed
 */
@property (nonatomic, assign, readwrite) BOOL enable;

/**
 * Indicate the BLE manager is busy with scanning or not
 */
@property (nonatomic, assign, readwrite) BOOL scanning;

/**
 * Indicate the BLE manager is busy with connecting peripheral or not
 */
@property (nonatomic, assign, readwrite) BOOL connecting;

/**
 * Indicate the BLE Manager is busy with enumerating peripheral or not
 */
@property (nonatomic, assign, readwrite) BOOL enumerating;

@property (nonatomic, strong) NSData *remainingBuffer;

@end


@implementation BLEManager

+ (instancetype)sharedInstance {
    static BLEManager *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [BLEManager new];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self setupDefaults];
    }
    return self;
}

- (void)setupDefaults {
    _discoverredPeripherals = [NSMutableDictionary dictionary];
    _connectedPeripherals = [NSMutableDictionary dictionary];
    _notificationCallbacks = [NSMutableDictionary dictionary];
    _enumeratedServices = [NSMutableDictionary dictionary];
    _absenceInterval = 10;
    _scanInterval = 5;
    _connectTimeout = 5;
    _enumerateTimeout = 5;
    _sendDataTimeout = 5;
    _continousScan = YES;
    
    dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0);
    _manager = [[CBCentralManager alloc] initWithDelegate:self queue:queue];
}

#pragma mark - Public

- (void)reset {
    weakify(self)
    [_connectedPeripherals enumerateKeysAndObjectsUsingBlock:^(NSUUID *key, BLEPeripheral *peripheral, BOOL * _Nonnull stop) {
        strongify(self)
        [strongself disconnectPeripheral:peripheral completion:^(id data, NSError *error) {
            peripheral.peripheral.delegate = nil;
        }];
    }];
    
    [_connectedPeripherals removeAllObjects];
    
    [_discoverredPeripherals removeAllObjects];
    
    self.connecting = NO;
    self.scanning = NO;
    self.enumerating = NO;
    
    _connectCompletion = nil;
    _enumerateCompletion = nil;
    _writeCompletion = nil;
    _disconnectCallback = nil;
    _scanCallback = nil;
    _disconnectCallback = nil;
    _notificationCallbacks = [NSMutableDictionary dictionary];
}

/// Scan peripherals
- (BOOL)scanPeripheralWithUUIDs:(NSArray<NSString *> *)uuids
                 resultCallback:(ScanCallback)callback {
    _scanCallback = callback;
    _scanUUIDs = uuids;
    
    if (self.manager.state != CBCentralManagerStatePoweredOn) {
        NSLog(@"[BLEManager] -ERROR-: BLE module is not enabled");
        return NO;
    }
    
    if (self.scanning) {
        NSLog(@"[BLEManager] -ERROR-: BLE module is already scanning peripherals!!");
        return NO;
    }
    
    NSMutableArray *cbuuid = [NSMutableArray array];
    [uuids enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [cbuuid addObject:[CBUUID UUIDWithString:obj]];
    }];
    
    [_manager scanForPeripheralsWithServices:cbuuid options:nil];
    self.scanning = YES;
    
    if (!_continousScan) {
        // One time scan, should stop when scan timeout reached
        weakify(self)
        dispatch_async(dispatch_get_main_queue(), ^{
            strongify(self)
            strongself.scanTimer = [NSTimer scheduledTimerWithTimeInterval:strongself.scanInterval
                                                                    target:strongself
                                                                  selector:@selector(scanTimeout:)
                                                                  userInfo:nil
                                                                   repeats:NO];
        });
    }
    
    NSLog(@"[BLEManager] -DEBUG-: Start scanning...");
    return YES;
}

- (void)stopScan {
    [self stopScanInternal];
    
    NSLog(@"[BLEManager] -DEBUG-: Scan stopped");
}

- (BLEPeripheral * _Nullable)getPeripheralByUUID:(NSUUID *)uuid {
    // Find the peripheral
    __block BLEPeripheral *peripheral = nil;
    [_discoverredPeripherals enumerateKeysAndObjectsUsingBlock:^(NSUUID * _Nonnull key, BLEPeripheral * _Nonnull obj, BOOL * _Nonnull stop) {
        if ([key.UUIDString isEqual:uuid.UUIDString]) {
            peripheral = obj;
            *stop = YES;
        }
    }];
    
    return peripheral;
}

- (void)scanTimeout:(NSTimer *)timer {
    [self stopScanInternal];
    
    NSLog(@"[BLEManager] -DEBUG-: Scan stopped");
}

- (void)connectTimeout:(NSTimer *)timer {
    NSUUID *peripheralUUID = [timer.userInfo objectForKey:@"uuid"];
    [_connectTimer invalidate];
    
    if (_connectCompletion) {
        NSError *err = [NSError errorWithDomain:ErrorDomain
                                           code:SBErrorCodeConnectTimeout
                                       userInfo:@{NSLocalizedDescriptionKey: @"Connect peripheral timeout"}];
        
        if (peripheralUUID) {
            BLEPeripheral *enumeratingPeripheral = [_connectedPeripherals objectForKey:peripheralUUID];
            enumeratingPeripheral.state = BLEPeripheralStateUnknown;
            [_connectedPeripherals removeObjectForKey:peripheralUUID];
        }

        _connectCompletion(@(NO), err);
        _connectCompletion = nil;
    }
    
    _connecting = NO;
    _enumerating = NO;
    _connectTimer = nil;
    _enumerateTimer = nil;
}

- (void)enumerateTimeout:(NSTimer *)timer {
    NSUUID *peripheralUUID = [timer.userInfo objectForKey:@"uuid"];
    [_enumerateTimer invalidate];
    
    if (_enumerateCompletion != nil) {
        NSError *err = [NSError errorWithDomain:ErrorDomain
                                           code:SBErrorCodeEnumerateTimeout
                                       userInfo:@{NSLocalizedDescriptionKey: @"Enumerate timeout"}];
        _enumerateCompletion(@(NO), err);
        _enumerateCompletion = nil;
        
        if (peripheralUUID) {
            BLEPeripheral *enumeratingPeripheral = [_connectedPeripherals objectForKey:peripheralUUID];
            enumeratingPeripheral.state = BLEPeripheralStateUnknown;
            [_connectedPeripherals removeObjectForKey:peripheralUUID];
        }
    }
    
    _connecting = NO;
    _enumerating = NO;
    _connectTimer = nil;
    _enumerateTimer = nil;
}

- (void)sendTimeout:(NSTimer *)timer {
    [_sendTimer invalidate];
    
    NSLog(@"[BLEManager] -ERROR-: Write characteristic value timeout");
    
    if (_writeCompletion) {
        NSError *err = [NSError errorWithDomain:ErrorDomain
                                           code:SBErrorCodeSendDataTimeout
                                       userInfo:@{NSLocalizedDescriptionKey: @"Write characteristic value timeout"}];
        _writeCompletion(@(NO), err);
        _writeCompletion = nil;
    }
}

/// Connect
- (BOOL)connectPeripheral:(BLEPeripheral *)peripheral completion:(ConnectCallback)completion {
    if (_connecting || _enumerating) {
        NSLog(@"[BLEManager] -ERROR-: BLEManager is busy with connecting peripheral, please try it later");
        return NO;
    }
    
    if (peripheral.state == BLEPeripheralStateEnumerated) {
        NSLog(@"[BLEManager] -WARN-: Peripheral already connected");
        return NO;
    }
    
    if (peripheral.state == BLEPeripheralStateConnected ||
        peripheral.state == BLEPeripheralStateConnecting ||
        peripheral.state == BLEPeripheralStateEnumerating) {
        NSLog(@"[BLEManager] -WARN-: Peripheral is connecting...");
        return NO;
    }
    
    NSLog(@"[BLEManager] -DEBUG-: Connecting peripheral %@", peripheral.identifier.UUIDString);
    
    peripheral.state = BLEPeripheralStateConnecting;
    
    [_connectedPeripherals setObject:peripheral forKey:peripheral.identifier];
    _connectCompletion = completion;
    _connecting = YES;
    
    NSDictionary *userinfo = nil;
    if (peripheral.identifier) {
        userinfo = @{@"uuid": peripheral.identifier};
    }
    
    _connectTimer = [NSTimer scheduledTimerWithTimeInterval:_connectTimeout
                                                     target:self
                                                   selector:@selector(connectTimeout:)
                                                   userInfo:userinfo
                                                    repeats:NO];
    
    [self.manager connectPeripheral:peripheral.peripheral options:nil];
    return YES;
}

/// Enumerate
- (void)enumeratePeripheral:(BLEPeripheral *)peripheral
                 completion:(ConnectCallback)completion {
    _enumerateCompletion = completion;
    
    peripheral.state = BLEPeripheralStateEnumerating;
    peripheral.peripheral.delegate = self;
    
    // Clear services & characteristics
    peripheral.services = nil;
    [peripheral.characteristics removeAllObjects];
    
    [peripheral.peripheral discoverServices:[self uuidStringsToCBUUID:self.scanUUIDs]];
    _enumerating = YES;
    
    NSDictionary *userinfo = nil;
    if (peripheral.identifier) {
        userinfo = @{@"uuid": peripheral.identifier};
    }
    
    _enumerateTimer = [NSTimer scheduledTimerWithTimeInterval:_enumerateTimeout
                                                       target:self
                                                     selector:@selector(enumerateTimeout:)
                                                     userInfo:userinfo
                                                      repeats:NO];
}

/// Subscribe notification for characteristic
- (BOOL)subscribeNotificationForPeripheral:(BLEPeripheral *)peripheral
                         forCharacteristic:(CBCharacteristic *)characteristic
                            resultCallback:(ValueUpdateCallback)completion {
    if (characteristic.properties & CBCharacteristicPropertyNotify) {
        [peripheral.peripheral setNotifyValue:YES forCharacteristic:characteristic];
        
        NSString *identifier = [NSString stringWithFormat:@"%@.%@",
                                peripheral.identifier,
                                characteristic.UUID.UUIDString];
        _notificationCallbacks[identifier] = completion;
        return YES;
    }
    
    NSLog(@"[BLEManager] -ERROR-: Characteristic is not allow to subscribe/unsubscribe");
    return NO;
}

/// Subscribe notification for characteristic UUID
- (BOOL)subscribeNotificationForPeripheral:(BLEPeripheral *)peripheral
                        characteristicUUID:(NSString *)characteristicUUID
                            resultCallback:(ValueUpdateCallback)callback {
    if (peripheral.state != BLEPeripheralStateEnumerated) {
        NSLog(@"Peripheral is not connected. Please make a connection first!!");
        return NO;
    }
    
    CBCharacteristic *charac = [self characteristicForPeripheral:peripheral UUID:characteristicUUID];
    if (charac == nil) {
        NSLog(@"[BLEManager] -ERROR-: Characteristic %@ does not exist", characteristicUUID);
        return NO;
    } else {
        return [self subscribeNotificationForPeripheral:peripheral
                                      forCharacteristic:charac
                                         resultCallback:callback];
    }
}

/// Unsubscribe notification for characteristic
- (BOOL)unsubscribeNotificationForPeripheral:(BLEPeripheral *)peripheral
                           forCharacteristic:(CBCharacteristic *)characteristic {
    if (peripheral.state != BLEPeripheralStateEnumerated) {
        NSLog(@"Peripheral is not connected. Please make a connection first!!");
        return NO;
    }
    
    if (characteristic.properties & CBCharacteristicPropertyNotify) {
        [peripheral.peripheral setNotifyValue:YES forCharacteristic:characteristic];
        NSString *identifier = [NSString stringWithFormat:@"%@.%@", peripheral.identifier, characteristic.UUID];
        if ([_notificationCallbacks objectForKey:identifier]) {
            [_notificationCallbacks removeObjectForKey:identifier];
        }
        return YES;
    }
    
    NSLog(@"[BLEManager] -ERROR-: Characteristic is not allow to subscribe/unsubscribe");
    return NO;
}

/// Send data to characteristic
- (BOOL)sendData:(NSData *)data
        toPeripheral:(BLEPeripheral *)peripheral
withCharacteristic:(CBCharacteristic *)characteristic
      completion:(_Nullable WriteResultCallback)completion {
    
    if (peripheral.state != BLEPeripheralStateEnumerated) {
        NSLog(@"Peripheral is not connected. Please make a connection first!!");
        return NO;
    }
    
    if ((characteristic.properties & CBCharacteristicPropertyWrite) ||
        (characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse)) {
        
        NSLog(@"[BLEManager] -DEBUG-: Sending data: %@...", data);
        
        if (completion) {
            if (characteristic.properties & CBCharacteristicPropertyWrite) {
                _writeCompletion = completion;
                
                NSData *packet;
                if ([data length] > BLE_MTU) {
                    // Remaining data
                    _remainingBuffer = [data subdataWithRange:NSMakeRange(BLE_MTU, data.length - BLE_MTU)];
                    packet = [data subdataWithRange:NSMakeRange(0, BLE_MTU)];
                } else {
                    _remainingBuffer = nil;  // No need to split packet
                    packet = data;
                }
                
                _sendTimer = [NSTimer scheduledTimerWithTimeInterval:_sendDataTimeout
                                                              target:self
                                                            selector:@selector(sendTimeout:)
                                                            userInfo:nil
                                                             repeats:YES];

                [peripheral.peripheral writeValue:packet
                            forCharacteristic:characteristic
                                         type:CBCharacteristicWriteWithResponse];
                
                return YES;
            } else {
                NSLog(@"[BLEManager] -WARN-: Characteristic do not support write response, fall back to write without response.");
            }
        }
        
        // No write response, so split the data in MTU Size, and send them separately
        for (int i = 0; i < data.length; i += BLE_MTU) {
            NSData *packet;
            if (i + BLE_MTU > data.length) {
                packet = [data subdataWithRange:NSMakeRange(i, data.length - i)];
            } else {
                packet = [data subdataWithRange:NSMakeRange(i, BLE_MTU)];
            }
            
            [peripheral.peripheral writeValue:packet
                            forCharacteristic:characteristic
                                         type:CBCharacteristicWriteWithoutResponse];
        }
        
        completion(@(YES), nil);
        
        return YES;
    }
    
    NSLog(@"[BLEManager] -ERROR-: Characteristic %@ do not support write values", characteristic.UUID);
    
    return NO;
}

- (CBCharacteristic *)characteristicForPeripheral:(BLEPeripheral *)peripheral UUID:(NSString *)UUID {
    __block CBCharacteristic *charac = nil;
    [peripheral.characteristics enumerateObjectsUsingBlock:^(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if ([obj.UUID.UUIDString isEqualToString:UUID]) {
            charac = obj;
            *stop = YES;
        }
    }];
    return charac;
}

/// Send data to characteristic (uuid)
-   (BOOL)sendData:(NSData *)data
      toPeripheral:(BLEPeripheral *)peripheral
characteristicUUID:(NSString *)characteristicUUID
        completion:(_Nullable WriteResultCallback)completion {
    CBCharacteristic *charac = [self characteristicForPeripheral:peripheral UUID:characteristicUUID];
    
    if (charac) {
        return [self sendData:data toPeripheral:peripheral withCharacteristic:charac completion:completion];
    } else {
        NSLog(@"[BLEManager] -ERROR-: Characteristic %@ does not exist", characteristicUUID);
        return NO;
    }
}

/// Disconnect BLE peripheral
- (BOOL)disconnectPeripheral:(BLEPeripheral *)peripheral
                  completion:(DisconnectCallback)completion {
    if (peripheral.state == BLEPeripheralStateEnumerated ||
        peripheral.state == BLEPeripheralStateEnumerating ||
        peripheral.state == BLEPeripheralStateConnected) {
        
        peripheral.peripheral.delegate = nil;

        _disconnectCallback = completion;

        NSLog(@"[BLEManager] Droping peripheral connection");
        [_manager cancelPeripheralConnection:peripheral.peripheral];
        return YES;
    }
    
    return NO;
}

/// Read value from peripheral's characteristic
- (BOOL)readPeripheral:(BLEPeripheral *)peripheral
    withCharacteristic:(CBCharacteristic *)characteristic
            completion:(ValueUpdateCallback)completion {
    if (peripheral.state != BLEPeripheralStateEnumerated) {
        NSLog(@"[BLEManager] -ERROR-: Peripheral not connected, please connect it first");
        return NO;
    }
    
    if (!(characteristic.properties & CBCharacteristicPropertyRead)) {
        NSLog(@"[BLEManager] -ERROR-: Peripheral read operation is not supported");
        return NO;
    }
    
    peripheral.peripheral.delegate = self;
    NSString *identifier = [NSString stringWithFormat:@"%@.%@", peripheral.identifier, characteristic.UUID];
    _notificationCallbacks[identifier] = completion;
    
    [peripheral.peripheral readValueForCharacteristic:characteristic];
    return YES;
}

#pragma mark - Private

/// Stop scan
- (void)stopScanInternal {
    [_scanTimer invalidate];
    _scanTimer = nil;
    _scanCallback = nil;
    
    [_manager stopScan];
    
    self.scanning = NO;
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:BLENotificationScanStopped object:nil userInfo:nil];
}

- (NSArray<CBUUID *> * _Nullable)uuidStringsToCBUUID:(NSArray<NSString *> * _Nullable)uuids {
    NSMutableArray *cbuuids = [NSMutableArray array];
    [uuids enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        CBUUID *uuid = [CBUUID UUIDWithString:obj];
        [cbuuids addObject:uuid];
    }];
    
    if ([uuids count] == 0) {
        return nil;
    }
    
    return [cbuuids copy];
}

#pragma mark - CBCentralManagerDelegate

- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    switch (central.state) {
        case CBManagerStateUnknown:
            NSLog(@"Unknown");
            self.enable = NO;
            break;
        case CBManagerStatePoweredOn:
            NSLog(@"Power on");
            self.enable = YES;
            break;
        case CBManagerStateResetting:
            NSLog(@"Resetting");
            self.enable = NO;
            break;
        case CBManagerStatePoweredOff:
            NSLog(@"Power off");
            self.enable = NO;
            break;
        case CBManagerStateUnsupported:
            NSLog(@"Unsupported");
            self.enable = NO;
            break;
        case CBManagerStateUnauthorized:
            NSLog(@"Not auth");
            self.enable = NO;
            break;
    }
    NSLog(@"state: %ld", (long)central.state);
}

- (void)centralManager:(CBCentralManager *)central willRestoreState:(NSDictionary<NSString *, id> *)dict {
    NSLog(@"-willRestoreState: %@", dict);
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary<NSString *, id> *)advertisementData RSSI:(NSNumber *)RSSI {
    NSLog(@"-didDiscoverPeripheral peripheral: %@, advertisementData: %@", peripheral.identifier.UUIDString, advertisementData);
    
    BLEPeripheral *blePeripheral = [_discoverredPeripherals objectForKey:peripheral.identifier];
    if (blePeripheral == nil) {
        blePeripheral = [BLEPeripheral new];
        blePeripheral.identifier = peripheral.identifier;
        blePeripheral.peripheral = peripheral;
        blePeripheral.rssi = [RSSI floatValue];
        _discoverredPeripherals[peripheral.identifier] = blePeripheral;
    } else {
        blePeripheral.rssi = [RSSI floatValue];
    }
    
    blePeripheral.lastSeen = [NSDate date];
    
    weakify(self)
    __weak typeof(_discoverredPeripherals) weakDiscoverPeripherals = _discoverredPeripherals;
    [_discoverredPeripherals enumerateKeysAndObjectsUsingBlock:^(NSUUID * _Nonnull key, BLEPeripheral * _Nonnull obj, BOOL * _Nonnull stop) {
        strongify(self)
        if ([obj.lastSeen timeIntervalSinceDate:[NSDate date]] > strongself.absenceInterval) {
            [weakDiscoverPeripherals removeObjectForKey:key];
        }
    }];
    
    if (_scanCallback) {
        _scanCallback(_discoverredPeripherals, nil);
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    NSLog(@"-didConnectPeripheral: peripheral %@ connected.", peripheral.identifier.UUIDString);
    _connecting = NO;
    [_connectTimer invalidate];
    _connectTimer = nil;
    
    BLEPeripheral *connectingPeripheral = [_connectedPeripherals objectForKey:peripheral.identifier];
    
    if (connectingPeripheral) {
        // Start enumerate
        [self enumeratePeripheral:connectingPeripheral completion:_connectCompletion];
        _connectCompletion = nil;
    } else {
        NSLog(@"[BLEManager] -Error-: internal error, peripheral %@ is not invoking by -connectPeripheral:completion",
              peripheral.identifier.UUIDString);
    }
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    NSLog(@"-didFailToConnectPeripheral: Failed to connect peripheral %@.", peripheral.identifier.UUIDString);
    [_connectTimer invalidate];
    _connectTimer = nil;
    _connecting = NO;

    [_connectedPeripherals removeObjectForKey:peripheral.identifier];
    
    if (_connectCompletion) {
        _connectCompletion(@(NO), error);
        _connectCompletion = nil;
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(nullable NSError *)error {
    if (error) {
        NSLog(@"[BLEManager] -ERROR-: Connection dropped for peripheral %@!!", peripheral.identifier.UUIDString);
    } else {
        NSLog(@"[BLEManager] -DEBUG-: Peripheral %@ disconnected!!", peripheral.identifier.UUIDString);
    }
    
    NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
    BLEPeripheral *blePeripheral = [_connectedPeripherals objectForKey:peripheral.identifier];
    if (blePeripheral) {
        blePeripheral.state = BLEPeripheralStateUnknown;
        userInfo[@"peripheral"] = blePeripheral;
    }
    
    [_connectedPeripherals removeObjectForKey:peripheral.identifier];
    
    if (_disconnectCallback) {
        _disconnectCallback(@(error == nil), error);
        _disconnectCallback = nil;
    }
    
    // Broadcast notification
    if (error) {
        userInfo[@"error"] = error;
        [[NSNotificationCenter defaultCenter]
         postNotificationName:BLENotificationDisconnected
         object:nil
         userInfo:userInfo];
    } else {
        [[NSNotificationCenter defaultCenter]
         postNotificationName:BLENotificationDisconnected
         object:nil
         userInfo:userInfo];
    }
}


#pragma mark - CBPeripheralDelegate


- (void)peripheralDidUpdateName:(CBPeripheral *)peripheral {
    NSLog(@"[BLEManager] -DEBUG-: peripheral name updated");
}

- (void)peripheral:(CBPeripheral *)peripheral didModifyServices:(NSArray<CBService *> *)invalidatedServices {
    NSLog(@"[BLEManager] -DEBUG-: peripheral %@ service modified", peripheral.identifier.UUIDString);
}

/// RSSI
- (void)peripheral:(CBPeripheral *)peripheral didReadRSSI:(NSNumber *)RSSI error:(NSError *)error {
    // Find the peripheral
    BLEPeripheral *blePeripheral = [self getPeripheralByUUID:peripheral.identifier];
    blePeripheral.rssi = [RSSI floatValue];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(nullable NSError *)error {
    if (error) {
        NSLog(@"[BLEManager] -ERROR-: Discover service error [%@]", error.localizedDescription);
        if (_enumerateCompletion) {
            _enumerateCompletion(@(NO), error);
            _enumerateCompletion = nil;
        }
    } else {
        NSLog(@"[BLEManager] -DEBUG-: Peripheral %@ services discoverred", peripheral.identifier.UUIDString);
        BLEPeripheral *enumeratingPeripheral = [_connectedPeripherals objectForKey:peripheral.identifier];
        enumeratingPeripheral.peripheral.delegate = self;
        enumeratingPeripheral.services = peripheral.services;
        [_enumeratedServices removeAllObjects];
        
        for (CBService *service in enumeratingPeripheral.peripheral.services) {
            _enumeratedServices[service.UUID] = @(NO);
            [enumeratingPeripheral.peripheral discoverCharacteristics:nil forService:service];
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverIncludedServicesForService:(CBService *)service error:(nullable NSError *)error {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(nullable NSError *)error {
    BLEPeripheral *enumeratingPeripheral = [_connectedPeripherals objectForKey:peripheral.identifier];

    if (_enumerateCompletion != nil && enumeratingPeripheral != nil) {
        _enumeratedServices[service.UUID] = @(YES);
        
        // Check enumerate finished or not
        __block BOOL enumerateFinished = YES;
        [_enumeratedServices enumerateKeysAndObjectsUsingBlock:^(CBUUID * _Nonnull key, NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
            if (![obj boolValue]) {
                // Not enumerate finished
                enumerateFinished = NO;
                *stop = YES;
            }
        }];
        
        NSLog(@"[BLEManager] -DEBUG-: Discover characteristics for peripheral %@ of service %@",
              peripheral.identifier.UUIDString,
              service.UUID.UUIDString);
        
        [service.characteristics enumerateObjectsUsingBlock:^(CBCharacteristic * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (![enumeratingPeripheral.characteristics containsObject:obj]) {
                [enumeratingPeripheral.characteristics addObject:obj];
            }
        }];
        
        if (enumerateFinished) {
            NSLog(@"[BLEManager] -DEBUG-: Peripheral Enumerate finished");
            
            BLEPeripheral *blePeripheral = [self getPeripheralByUUID:peripheral.identifier];
            if (blePeripheral) {
                enumeratingPeripheral.state = BLEPeripheralStateEnumerated;
            } else {
                NSLog(@"[BLEManager] -Error-: Enumerated peripheral is not found in the scan list");
            }
            
            _enumerating = NO;
            _enumerateCompletion(@(YES), nil);
            _enumerateCompletion = nil;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    NSString *identifier = [NSString stringWithFormat:@"%@.%@", peripheral.identifier, characteristic.UUID];
    ValueUpdateCallback notificationCallback = [_notificationCallbacks objectForKey:identifier];
    NSLog(@"[BLEManager] -DEBUG-: Update value for characteristic %@, value %@", characteristic.UUID.UUIDString, characteristic.value);
    if (notificationCallback != nil) {
        notificationCallback(characteristic.value, error);
    } else {
        
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    NSLog(@"[BLEManager] -DEBUG-: Write value to characteristic %@ %@ [%@]",
          characteristic.UUID,
          error == nil ? @"success" : @"failed",
          error.localizedDescription);
    
    [_sendTimer invalidate];
    _sendTimer = nil;
    
    if (_remainingBuffer != nil) {
        // More data to send
        NSData *packet;
        if ([_remainingBuffer length] > BLE_MTU) {
            // Remaining data
            packet = [_remainingBuffer subdataWithRange:NSMakeRange(0, BLE_MTU)];
            _remainingBuffer = [_remainingBuffer subdataWithRange:NSMakeRange(BLE_MTU, _remainingBuffer.length - BLE_MTU)];
        } else {
            packet = _remainingBuffer;
            _remainingBuffer = nil;  // No need to split packet
        }
        
        _sendTimer = [NSTimer scheduledTimerWithTimeInterval:_sendDataTimeout
                                                      target:self
                                                    selector:@selector(sendTimeout:)
                                                    userInfo:nil
                                                     repeats:YES];
        
        [peripheral writeValue:packet
             forCharacteristic:characteristic
                          type:CBCharacteristicWriteWithResponse];
    } else {
        // No more data to send
        if (_writeCompletion) {
            _writeCompletion(@(error == nil), error);
            _writeCompletion = nil;
        }
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    if (error) {
        NSLog(@"[BLEManager] -ERROR-: Failed to change notification state for characteristic: %@", characteristic.UUID.UUIDString);
        NSString *identifier = [NSString stringWithFormat:@"%@.%@", peripheral.identifier, characteristic.UUID];
        [_notificationCallbacks removeObjectForKey:identifier];
    } else {
        NSLog(@"[BLEManager] -DEBUG-: Characteristic %@ notification state updated to %@",
              characteristic.UUID,
              characteristic.isNotifying ? @"notifying" : @"notNotify");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverDescriptorsForCharacteristic:(CBCharacteristic *)characteristic error:(nullable NSError *)error {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error {
    
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForDescriptor:(CBDescriptor *)descriptor error:(nullable NSError *)error {
    
}

@end
