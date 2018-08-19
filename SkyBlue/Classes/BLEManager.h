//
//  BLEManager.h
//  SkyBlue
//
//  Created by Enix Yu on 30/5/2018.
//  Copyright © 2018 LinkJob. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class BLEPeripheral;

// -------------------------------------------------------------------------
#pragma mark - Error code
// -------------------------------------------------------------------------

/// Error code
typedef NS_ENUM(NSUInteger, SBErrorCode) {
    /// Connect peripheral timeout
    SBErrorCodeConnectTimeout = -10001,
    
    /// Enumerate peripheral timeout
    SBErrorCodeEnumerateTimeout = -10002,
    
    /// Send data to  peripheral timeout
    SBErrorCodeSendDataTimeout = -10003,
};

// -------------------------------------------------------------------------
#pragma mark - Callbacks
// -------------------------------------------------------------------------

/// Scan result callback
typedef void(^ScanCallback)(NSDictionary<NSUUID *, BLEPeripheral *> * _Nullable discoverredPeripherals,
                            NSError * _Nullable error);

// -------------------------------------------------------------------------

/// Connect peripheral callback (if success, success = @(YES), otherwise, error will be the reason
typedef void(^ConnectCallback)(NSNumber *success, NSError * _Nullable error);

// -------------------------------------------------------------------------

/// Characteristic value update callback
typedef void(^ValueUpdateCallback)(NSData * _Nullable data, NSError * _Nullable error);

// -------------------------------------------------------------------------

/// Callback for disconnect peripheral operation
typedef void(^DisconnectCallback)(NSNumber * _Nullable success, NSError * _Nullable error);

// -------------------------------------------------------------------------

/// Callback for write operation (only available when peripheral support `Write with response`
typedef void(^WriteResultCallback)(NSNumber * _Nullable success, NSError * _Nullable error);

// -------------------------------------------------------------------------
#pragma mark - Notification
// -------------------------------------------------------------------------

/// Disconnect notification
extern NSString *BLENotificationDisconnected;

/// Scan stop notification
extern NSString *BLENotificationScanStopped;

// -------------------------------------------------------------------------
@interface BLEManager : NSObject
// -------------------------------------------------------------------------


// -------------------------------------------------------------------------
#pragma mark - properties
// -------------------------------------------------------------------------


/**
 * Internal CBCentralManager
 */
@property (nonatomic, strong) CBCentralManager *bleManager;

/**
 * The discoverred ble peripheral list
 */
@property (nonatomic, strong, readonly) NSDictionary<NSUUID *, BLEPeripheral *> *discoverredPeripherals;

/**
 * The connected ble peripheral list
 */
@property (nonatomic, strong, readonly) NSDictionary<NSUUID *, BLEPeripheral *> *connectedPeripherals;

/**
 * Scan peripheral interval
 */
@property (nonatomic, assign) NSTimeInterval scanInterval;

/**
 * How many seconds are passed when peripheral last seen by scan
 */
@property (nonatomic, assign) NSTimeInterval absenceInterval;

/**
 * Whether trigger continous peripheral scan. Scan will be stopped until user invoke -stopScan:
 */
@property (nonatomic, assign) BOOL continousScan;

/**
 * Connect peripheral timeout interval. If both -didConnectPeripheral: and -didFailToConnectPeripheral:error: are not being called,
 * `connectCompletion` callback will be called with a timeout error.
 */
@property (nonatomic, assign) NSTimeInterval connectTimeout;

/**
 * The timeout interval for enumeration
 */
@property (nonatomic, assign) NSTimeInterval enumerateTimeout;

/**
 * The timeout interval for write with response operation
 */
@property (nonatomic, assign) NSTimeInterval sendDataTimeout;

/**
 * Whether BLE module is enable or not. If not, then scan/connect will not be performed
 */
@property (nonatomic, readonly) BOOL enable;

/**
 * Indicate the BLE manager is busy with scanning or not
 */
@property (nonatomic, readonly) BOOL scanning;

/**
 * Indicate the BLE manager is busy with connecting peripheral or not
 */
@property (nonatomic, readonly) BOOL connecting;

/**
 * Indicate the BLE Manager is busy with enumerating peripheral or not
 */
@property (nonatomic, readonly) BOOL enumerating;


// -------------------------------------------------------------------------
#pragma mark - Public API
// -------------------------------------------------------------------------


/**
 * Get singleton instance
 */
+ (instancetype)sharedInstance;


// -------------------------------------------------------------------------


/**
 * Reset the SDK
 */
- (void)reset;


// -------------------------------------------------------------------------


/**
 * Scan BLE peripherals
 *
 * @param uuids         The service UUID list for scan filtering
 * @param callback      The callback is invoke when a peripheral is discoverred.
 * @return              YES if scan operation succcess, NO if scan operation is not triggered.
 */
- (BOOL)scanPeripheralWithUUIDs:(NSArray<NSString *> * _Nullable)uuids
                 resultCallback:(ScanCallback)callback;


// -------------------------------------------------------------------------


/**
 * Stop scanning BLE peripheral
 */
- (void)stopScan;

/**
 * Connect to BLE peripheral
 *
 * @param peripheral        The peripheral you need to connect
 * @param completion        Completion will be invoked when connect is done or failed.
 */
- (BOOL)connectPeripheral:(BLEPeripheral *)peripheral
               completion:(ConnectCallback)completion;

// -------------------------------------------------------------------------


/**
 * Subscribe notification for characteristic.
 *
 * @param peripheral        The BLE peripheral
 * @param characteristic    The BLE charactersitic to subscribe
 * @param callback          The callback will be invoke when notification is come
 */
- (BOOL)subscribeNotificationForPeripheral:(BLEPeripheral *)peripheral
                         forCharacteristic:(CBCharacteristic *)characteristic
                            resultCallback:(ValueUpdateCallback)callback;

// -------------------------------------------------------------------------


/**
 * Subscribe notification for characteristic UUID.
 *
 * @param peripheral            The BLE peripheral
 * @param characteristicUUID    The BLE charactersitic to subscribe
 * @param callback              The callback will be invoke when notification is come
 */
- (BOOL)subscribeNotificationForPeripheral:(BLEPeripheral *)peripheral
                        characteristicUUID:(NSString *)characteristicUUID
                            resultCallback:(ValueUpdateCallback)callback;

// -------------------------------------------------------------------------


/**
 * Unsubscribe notification for characteristic
 *
 * @param peripheral        The BLE peripheral
 * @param characteristic    The characteristic to unsubscribe
 * @return:                 YES if operation success, NO if not.
 */
- (BOOL)unsubscribeNotificationForPeripheral:(BLEPeripheral *)peripheral
                           forCharacteristic:(CBCharacteristic *)characteristic;

// -------------------------------------------------------------------------


/**
 * Disconnect BLE peripheral
 *
 * @param peripheral        The BLE peripheral to be disconnected
 * @param completion        The callback will be invoke when disconnected
 * @return:                 YES if operation success, NO if not.
 */
- (BOOL)disconnectPeripheral:(BLEPeripheral *)peripheral
                  completion:(DisconnectCallback)completion;


// -------------------------------------------------------------------------


/**
 * Send data to characteristic
 *
 * @param data              The data to be sent
 * @param peripheral        Send data to which peripheral
 * @param characteristic    Send data to which characteristic
 * @param completion        The callback will be invoke when write operation is finished
 * @return                  YES if operation success, NO if not
 */
-   (BOOL)sendData:(NSData *)data
      toPeripheral:(BLEPeripheral *)peripheral
withCharacteristic:(CBCharacteristic *)characteristic
        completion:(_Nullable WriteResultCallback)completion;


// -------------------------------------------------------------------------


/**
 * Send data to characteristic (uuid)
 *
 * @param data                  The data to be sent
 * @param peripheral            Send data to which peripheral
 * @param characteristicUUID    Send data to which characteristic uuid
 * @param completion            The callback will be invoke when write operation is finished
 * @return                      YES if operation success, NO if not
 */
-   (BOOL)sendData:(NSData *)data
      toPeripheral:(BLEPeripheral *)peripheral
characteristicUUID:(NSString *)characteristicUUID
        completion:(_Nullable WriteResultCallback)completion;


// -------------------------------------------------------------------------


/**
 * Read value from peripheral's characteristic
 *
 * @param peripheral        The peripheral to be read
 * @param characteristic    The characterisitc to be read
 * @param completion        The callback will be invoke when read operation is finished
 * @return:                 YES if operation success, NO if not.
 */
- (BOOL)readPeripheral:(BLEPeripheral *)peripheral
    withCharacteristic:(CBCharacteristic *)characteristic
            completion:(ValueUpdateCallback)completion;


// -------------------------------------------------------------------------

@end

NS_ASSUME_NONNULL_END
