//
//  SBSessionController.m
//  SkyBlue_Example
//
//  Created by Enix Yu on 21/7/2018.
//  Copyright © 2018 enix223. All rights reserved.
//

#import "SBSessionController.h"

#import "NSData+Printable.h"
#import "NSString+Hex.h"

@import SkyBlue;

typedef void(^IncomeDataCallback)(NSData * _Nullable data, NSError * _Nullable error);

@interface SBSessionController ()

@property (nonatomic, strong) BLEManager *bleManager;

@property (nonatomic, strong) NSMutableString *recvString;

@property (nonatomic, strong) IncomeDataCallback dataCallback;

@end

@implementation SBSessionController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.recvString = [NSMutableString string];
    self.bleManager = [BLEManager sharedInstance];
    
    [self setupCallback];
    
    if ((_characteristic.properties & CBCharacteristicPropertyRead) == CBCharacteristicPropertyRead) {
        // Enable read if characteristic support read operation
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                                  initWithTitle:@"Read"
                                                  style:UIBarButtonItemStylePlain
                                                  target:self
                                                  action:@selector(readDidTap)];
    }
    
    if ((_characteristic.properties & CBCharacteristicPropertyNotify) == CBCharacteristicPropertyNotify) {
        // Subscribe characteristic automatically
        [_bleManager subscribeNotificationForPeripheral:_peripheral
                                      forCharacteristic:_characteristic
                                         resultCallback:_dataCallback];
    }
    
    if ((_characteristic.properties & CBCharacteristicPropertyWrite) != CBCharacteristicPropertyWrite &&
        (_characteristic.properties & CBCharacteristicPropertyWriteWithoutResponse) != CBCharacteristicPropertyWriteWithoutResponse ) {
        // Can not write
        [_sendButton setEnabled:NO];
    }
}

- (void)setupCallback {
    __weak typeof(self) weakself = self;
    _dataCallback = ^(NSData *data, NSError *error) {
        __strong typeof(weakself) strongself = weakself;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                NSLog(@"Read error");
            } else {
                NSString *hexString = [data hexString];
                [strongself.recvString appendString:@"\n"];
                [strongself.recvString appendString:hexString];
                
                strongself.recvTextview.text = strongself.recvString;
            }
        });
    };
}

- (void)readDidTap {
    [_bleManager readPeripheral:_peripheral
             withCharacteristic:_characteristic
                     completion:_dataCallback];
}

- (IBAction)sendDidTap:(id)sender {
    NSString *dataHex = _sendTextfield.text;
    NSRegularExpression *exp = [NSRegularExpression
                                regularExpressionWithPattern:@"^[0-9a-fA-F]{2}( [0-9A-Fa-f]{2})*$"
                                options:kNilOptions
                                error:nil];
    
    NSArray *matches = [exp matchesInString:dataHex options:kNilOptions range:NSMakeRange(0, dataHex.length)];
    if ([matches count] == 0) {
        NSLog(@"Data format not valid! Should be like this: F0 F1 FF ....");
        return;
    }
    
    NSData *data = [dataHex getHexData];
    [_bleManager sendData:data
             toPeripheral:_peripheral
       withCharacteristic:_characteristic
               completion:^(id data, NSError *error) {
                   if (!error) {
                       NSLog(@"Data sent");
                   }
               }];
}

@end
