//
//  SBSettingController.m
//  SkyBlue_Example
//
//  Created by Enix Yu on 19/8/2018.
//  Copyright © 2018 enix223. All rights reserved.
//


#import "SBSettingController.h"

@import SkyBlue;

@interface SBSettingController () <UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *scanIntervalTextfield;

@property (weak, nonatomic) IBOutlet UISwitch *continousScanSwitch;

@property (weak, nonatomic) IBOutlet UITextField *connectTimeoutTextfield;

@property (weak, nonatomic) IBOutlet UITextField *enumerateTimeoutTextfield;

@property (weak, nonatomic) IBOutlet UITextField *sendDataTimeoutTextfield;

@property (nonatomic, strong)  BLEManager *manager;

@end

@implementation SBSettingController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _manager = [BLEManager sharedInstance];
    
    _scanIntervalTextfield.delegate = self;
    _connectTimeoutTextfield.delegate = self;
    _enumerateTimeoutTextfield.delegate = self;
    _sendDataTimeoutTextfield.delegate = self;
    
    [_continousScanSwitch addTarget:self action:@selector(switchDidChanged:)
                   forControlEvents:UIControlEventValueChanged];
    
    _scanIntervalTextfield.text = [NSString stringWithFormat:@"%.2f", _manager.scanInterval];
    _connectTimeoutTextfield.text = [NSString stringWithFormat:@"%.2f", _manager.connectTimeout];
    _enumerateTimeoutTextfield.text = [NSString stringWithFormat:@"%.2f", _manager.enumerateTimeout];
    _sendDataTimeoutTextfield.text = [NSString stringWithFormat:@"%.2f", _manager.sendDataTimeout];
    
    _continousScanSwitch.on = _manager.continousScan;
}

- (void)switchDidChanged:(UISwitch *)sender {
    _manager.continousScan = sender.on;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_scanIntervalTextfield resignFirstResponder];
    [_connectTimeoutTextfield resignFirstResponder];
    [_enumerateTimeoutTextfield resignFirstResponder];
    [_sendDataTimeoutTextfield resignFirstResponder];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField == _scanIntervalTextfield) {
        _manager.scanInterval = [textField.text floatValue];
    } else if (textField == _connectTimeoutTextfield) {
        _manager.connectTimeout = [textField.text floatValue];
    } else if (textField == _enumerateTimeoutTextfield) {
        _manager.enumerateTimeout = [textField.text floatValue];
    } else if (textField == _sendDataTimeoutTextfield) {
        _manager.sendDataTimeout = [textField.text floatValue];
    }
    
    [textField resignFirstResponder];
}

@end
