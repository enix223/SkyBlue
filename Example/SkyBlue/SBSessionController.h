//
//  SBSessionController.h
//  SkyBlue_Example
//
//  Created by Enix Yu on 21/7/2018.
//  Copyright © 2018 enix223. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CBCharacteristic, BLEPeripheral;

@interface SBSessionController : UIViewController

@property (nonatomic, strong) BLEPeripheral *peripheral;
@property (nonatomic, strong) CBCharacteristic *characteristic;

@property (weak, nonatomic) IBOutlet UITextField *sendTextfield;
@property (weak, nonatomic) IBOutlet UIButton *sendButton;
@property (weak, nonatomic) IBOutlet UITextView *recvTextview;

@end
