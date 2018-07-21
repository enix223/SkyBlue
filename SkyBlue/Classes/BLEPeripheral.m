//
//  BLEPeripheral.m
//  SkyBlue
//
//  Created by Enix Yu on 30/5/2018.
//  Copyright © 2018 LinkJob. All rights reserved.
//

#import "BLEPeripheral.h"

@implementation BLEPeripheral

- (BOOL)isEqual:(BLEPeripheral *)object {
    return [self.identifier isEqual:object.identifier];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.state = BLEPeripheralStateUnknown;
        self.characteristics = [NSMutableArray array];
    }
    return self;
}

@end
