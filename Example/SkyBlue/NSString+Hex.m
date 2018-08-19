//
//  NSString+Hex.m
//  SkyBlue_Example
//
//  Created by Enix Yu on 19/8/2018.
//  Copyright © 2018 enix223. All rights reserved.
//

#import "NSString+Hex.h"

@implementation NSString (Hex)

- (NSData *)getHexData {
    NSRegularExpression *regexp = [NSRegularExpression regularExpressionWithPattern:@"[0-9a-fA-F]{2}"
                                                                            options:kNilOptions
                                                                              error:nil];
    
    NSMutableData *data = [NSMutableData data];
    
    [regexp
     enumerateMatchesInString:self
     options:kNilOptions
     range:NSMakeRange(0, self.length)
     usingBlock:^(NSTextCheckingResult * _Nullable result, NSMatchingFlags flags, BOOL * _Nonnull stop) {
         NSString *match = [self substringWithRange:result.range];
         NSScanner *scanner = [NSScanner scannerWithString:match];
         unsigned int hex;
         [scanner scanHexInt:&hex];
         [data appendBytes:&hex length:1];
     }];
    
    return [data copy];
}

@end
