//
//  SBViewController.m
//  SkyBlue
//
//  Created by enix223 on 07/21/2018.
//  Copyright (c) 2018 enix223. All rights reserved.
//

#import "SBViewController.h"
#import "SBSettingController.h"
#import "SBDetailController.h"


@import SkyBlue;

@interface SBViewController () <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) UIBarButtonItem *right;

@property (nonatomic, strong) BLEManager *bleManager;

@property (nonatomic, strong) NSMutableArray<BLEPeripheral *> *devices;

@end

@implementation SBViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"SkyBlue";
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [UIView new];
    self.devices = [NSMutableArray array];
    
    _right = [[UIBarButtonItem alloc]
              initWithTitle:@"Scan"
              style:UIBarButtonItemStylePlain
              target:self
              action:@selector(scanDidTap:)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithTitle:@"Setting"
                                             style:UIBarButtonItemStylePlain
                                             target:self
                                             action:@selector(settingDidTap)];
    
    self.bleManager = [BLEManager sharedInstance];
    
    self.navigationItem.rightBarButtonItem = _right;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.bleManager addObserver:self forKeyPath:@"scanning" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.bleManager removeObserver:self forKeyPath:@"scanning"];
    
    [super viewWillDisappear:animated];
}

- (void)settingDidTap {
    SBSettingController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil]
                               instantiateViewControllerWithIdentifier:@"SBSettingController"];
    
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)scanDidTap:(id)sender {
    if (_bleManager.scanning) {
        [_bleManager stopScan];
    } else {
        [self refreshDevice];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"scanning"]) {
        BOOL scanning = [[change objectForKey:NSKeyValueChangeNewKey] boolValue];
        if (scanning) {
            [self.right setTitle:@"stop"];
        } else {
            [self.right setTitle:@"scan"];
        }
    }
}

#pragma mark - BLE Stuff

- (void)refreshDevice{
    if (_bleManager.scanning) {
        [_bleManager stopScan];
    }
    
    [self.devices removeAllObjects];
    [_bleManager reset];
    
    __weak typeof(self) weakself = self;
    [_bleManager scanPeripheralWithUUIDs:nil resultCallback:^(BLEPeripheral *dev, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakself) strongself = weakself;
            __block BOOL found = NO;
            
            if ([weakself.devices count] == 0) {
                [weakself.devices addObject:dev];
                [strongself.tableView reloadData];
            } else {
                [weakself.devices enumerateObjectsUsingBlock:^(BLEPeripheral * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([obj.identifier isEqual:dev.identifier]) {
                        found = YES;
                        *stop  = YES;
                    }
                }];

                if (!found) {
                    NSIndexPath *path = [NSIndexPath indexPathForRow:[weakself.devices count] inSection:0];
                    [weakself.devices addObject:dev];
                    [strongself.tableView insertRowsAtIndexPaths:@[path] withRowAnimation:UITableViewRowAnimationAutomatic];
                }
            }
        });
    }];
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return [_devices count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 50.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"cell"];
    }
    
    BLEPeripheral *peripheral = [self.devices objectAtIndex:indexPath.row];
    
    cell.textLabel.text = peripheral.peripheral.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"RSSI: %ld", (long) peripheral.rssi];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [_bleManager stopScan];
    
    SBDetailController *vc = [[UIStoryboard storyboardWithName:@"Main" bundle:nil]
                              instantiateViewControllerWithIdentifier:@"SBDetailController"];
    
    BLEPeripheral *peripheral = [self.devices objectAtIndex:indexPath.row];
    vc.peripheral = peripheral;
    [self.navigationController pushViewController:vc animated:YES];
}

@end
