//
//  BLEPeripheral.h
//  SkyBlue
//
//  Created by Enix Yu on 30/5/2018.
//  Copyright © 2018 LinkJob. All rights reserved.
//

#import <CoreBluetooth/CoreBluetooth.h>
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, BLEPeripheralState) {
    BLEPeripheralStateUnknown = 0,
    BLEPeripheralStateConnecting = 3,
    BLEPeripheralStateConnected = 4,
    BLEPeripheralStateEnumerating = 1,
    BLEPeripheralStateEnumerated = 2,
};

@interface BLEPeripheral : NSObject

/**
 * Bluetooth peripheral last seen datetime
 */
@property (nonatomic, strong) NSDate *lastSeen;

/**
 * The RSSI value
 */
@property (nonatomic, assign) NSInteger rssi;

/**
 * The internal CBPeripheral object
 */
@property (nonatomic, strong) CBPeripheral *peripheral;

/**
 * The peripheral identifier
 */
@property (nonatomic, strong) NSUUID *identifier;

/**
 * The BLE peripheral state
 */
@property (nonatomic, assign) BLEPeripheralState state;

/**
 * The associate services for this peripheral
 */
@property (nonatomic, strong) NSArray<CBService *> *services;

/**
 * All the characteristics for this peripheral
 */
@property (nonatomic, strong) NSMutableArray<CBCharacteristic *> *characteristics;


@end
