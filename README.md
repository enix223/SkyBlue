# SkyBlue

[![CI Status](https://img.shields.io/travis/enix223/SkyBlue.svg?style=flat)](https://travis-ci.org/enix223/SkyBlue)
[![Version](https://img.shields.io/cocoapods/v/SkyBlue.svg?style=flat)](https://cocoapods.org/pods/SkyBlue)
[![License](https://img.shields.io/cocoapods/l/SkyBlue.svg?style=flat)](https://cocoapods.org/pods/SkyBlue)
[![Platform](https://img.shields.io/cocoapods/p/SkyBlue.svg?style=flat)](https://cocoapods.org/pods/SkyBlue)

## Example

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

OS >= iOS 8.0

## Installation

SkyBlue is available through [CocoaPods](https://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod 'SkyBlue'
```

## How to use

1. Get single instance

```objc
self.bleManager = [BLEManager sharedInstance];
```

2. Scan

```objc
[_bleManager scanPeripheralWithUUIDs:uuids resultCallback:^(NSDictionary *devices, NSError *error) {
    NSMutableArray *devs = [NSMutableArray array];
    [devices enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        NSLog(@"Device UUID: @%", key);
        BLEPeripheral *device = obj;
        // Do anything you need with BLEPeripheral
    }];
}];
```

3. Connect

```objc
[_bleManager connectPeripheral:peripheral completion:^(id data, NSError *error) {
    if (error) {
        NSLog(@"Failed to connect BLE Peripheral");
    } else {
        // Connected
        Do everything you need after connected
    }
}];
```

4. You can access the connected device with`connectedPeripherals`, this is a NSDictionary<NSUUID *, BLEPeripheral *> to keep the connected peripherals. The key is the peripheral UUID. 

```objc
_bleManager.connectedPeripherals
```

5. Subscribe/Unsubscribe

```objc

// Subscribe
[_bleManager subscribeNotificationForPeripheral:peripheral
                             characteristicUUID:BLE_CHARACTERISTIC_UUID   // Characteristic UUID String, eg. FFE1
                                 resultCallback:^(NSData *data, NSError *error) {
                                    if (error) {
                                        NSLog(@"Error: %@", error.localizedDescription);
                                    } else {
                                        // Processing `data` as you want
                                    }
                                 }];
                                 
// Unsubscribe
[_bleManager unsubscribeNotificationForPeripheral:peripheral
                                forCharacteristic:characteristic];
```

6. Read

```objc
[_bleManager readPeripheral:peripheral withCharacteristic:characteristic completion:^(NSData *data, NSError *error) {
    // Error is not null if read fail
}];
```

7. Write

```objc
[_bleManager sendData:data
 toPeripheral:peripheral
 characteristicUUID:characteristicUUID
 completion:^(id res, NSError *error) {
    // error indicate the write operation is success or not
 }];
```

8. Disconnect

```objc
[_bleManager disconnectPeripheral:peripheral
                       completion:^(NSData *data, NSError *error) {
                            // Indicate disconnect or not
                       };
```

9. Notification

```objc
/// Disconnect notification
extern NSString *BLENotificationDisconnected;

/// Scan stop notification
extern NSString *BLENotificationScanStopped;

```

## Author

enix223, enix223@163.com

## License

SkyBlue is available under the MIT license. See the LICENSE file for more info.