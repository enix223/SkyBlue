//
//  SBDetailController.m
//  SkyBlue_Example
//
//  Created by Enix Yu on 19/8/2018.
//  Copyright © 2018 enix223. All rights reserved.
//

#import "SBDetailController.h"
#import "SBSessionController.h"

@import SkyBlue;


@interface SBDetailController () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) BLEManager *bleManager;

@property (nonatomic, strong) UIBarButtonItem *right;

@end

@implementation SBDetailController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.tableFooterView = [UIView new];
    
    _bleManager = [BLEManager sharedInstance];
    
    if (_peripheral != nil) {
        __weak typeof(self) weakself = self;
        [_bleManager connectPeripheral:_peripheral completion:^(id data, NSError *error) {
            __strong typeof(weakself) strongself = weakself;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    NSLog(@"Connect peripheral failed");
                } else {
                    [strongself.tableView reloadData];
                }
            });
        }];
    }
    
    _right = [[UIBarButtonItem alloc]
              initWithTitle:@"Disconnect"
              style:UIBarButtonItemStylePlain
              target:self
              action:@selector(disconnect)];

    if (_peripheral.state == BLEPeripheralStateEnumerated) {
        self.navigationItem.rightBarButtonItem = self.right;
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }
    
    [self.peripheral addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)dealloc {
    [self.peripheral removeObserver:self forKeyPath:@"state"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"state"]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Show disconnect btn when peripheral connected
            BLEPeripheralState state = [[change objectForKey:NSKeyValueChangeNewKey] intValue];
            if (state == BLEPeripheralStateEnumerated) {
                self.navigationItem.rightBarButtonItem = self.right;
            } else {
                self.navigationItem.rightBarButtonItem = nil;
            }
        });
    }
}

- (void)disconnect {
    __weak typeof(self) weakself = self;
    [_bleManager disconnectPeripheral:_peripheral completion:^(id data, NSError *error) {
        __strong typeof(weakself) strongself = weakself;
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongself.navigationController popViewControllerAnimated:YES];
        });
    }];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return [_peripheral.services count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    CBService *service = [_peripheral.services objectAtIndex:section];
    return [service.characteristics count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    CBService *service = [_peripheral.services objectAtIndex:section];
    return [service.UUID.UUIDString substringToIndex:4];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 40.0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 60.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"cell"];
    }
    
    CBService *service = [_peripheral.services objectAtIndex:indexPath.section];
    CBCharacteristic *charac = [service.characteristics objectAtIndex:indexPath.row];
    
    cell.textLabel.text = [charac.UUID.UUIDString substringToIndex:4];
    cell.textLabel.textColor = [UIColor darkGrayColor];
    
    NSMutableString *properties = [NSMutableString string];
    if ((charac.properties & CBCharacteristicPropertyRead) == CBCharacteristicPropertyRead) {
        [properties appendString:@"R "];
    }
    
    if ((charac.properties & CBCharacteristicPropertyWrite) == CBCharacteristicPropertyWrite) {
        [properties appendString:@"WR "];
    }
    
    if ((charac.properties & CBCharacteristicPropertyNotify) == CBCharacteristicPropertyNotify) {
        [properties appendString:@"N "];
    }
    
    if ((charac.properties & CBCharacteristicPropertyIndicate) == CBCharacteristicPropertyIndicate) {
        [properties appendString:@"I "];
    }
    
    if ((charac.properties & CBCharacteristicPropertyWriteWithoutResponse) == CBCharacteristicPropertyWriteWithoutResponse) {
        [properties appendString:@"W "];
    }
    
    if ((charac.properties & CBCharacteristicPropertyBroadcast) == CBCharacteristicPropertyBroadcast) {
        [properties appendString:@"B "];
    }
    
    if ((charac.properties & CBCharacteristicPropertyExtendedProperties) == CBCharacteristicPropertyExtendedProperties) {
        [properties appendString:@"E "];
    }
    
    if ((charac.properties & CBCharacteristicPropertyNotifyEncryptionRequired) == CBCharacteristicPropertyNotifyEncryptionRequired) {
        [properties appendString:@"NE "];
    }
    
    if ((charac.properties & CBCharacteristicPropertyAuthenticatedSignedWrites) == CBCharacteristicPropertyAuthenticatedSignedWrites) {
        [properties appendString:@"ASW "];
    }
    
    if ((charac.properties & CBCharacteristicPropertyIndicateEncryptionRequired) == CBCharacteristicPropertyIndicateEncryptionRequired) {
        [properties appendString:@"IE "];
    }
    
    cell.detailTextLabel.text = properties;
    cell.detailTextLabel.textColor = [UIColor redColor];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    CBService *service = [_peripheral.services objectAtIndex:indexPath.section];
    CBCharacteristic *charac = [service.characteristics objectAtIndex:indexPath.row];
    
    SBSessionController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil]
                               instantiateViewControllerWithIdentifier:@"SBSessionController"];
    
    vc.peripheral = _peripheral;
    vc.characteristic = charac;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
