//
//  NSData+Printable.m
//  SkyBlue_Example
//
//  Created by Enix Yu on 19/8/2018.
//  Copyright © 2018 enix223. All rights reserved.
//

#import "NSData+Printable.h"

@implementation NSData (Printable)

- (NSString *)hexString {
    UInt8 *bytes = (UInt8 *) self.bytes;
    NSMutableString *str = [NSMutableString string];
    for (int i = 0; i < self.length; i ++) {
        [str appendFormat:@"%02X ", bytes[i]];
    }
    return [str copy];
}

@end
