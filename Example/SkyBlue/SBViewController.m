//
//  SBViewController.m
//  SkyBlue
//
//  Created by enix223 on 07/21/2018.
//  Copyright (c) 2018 enix223. All rights reserved.
//

#import "SBViewController.h"

@import SkyBlue;

@interface SBViewController () <UITableViewDataSource, UITableViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) UIBarButtonItem *right;

@property (nonatomic, assign) BOOL scanning;

@property (nonatomic, strong) BLEManager *bleManager;

@property (nonatomic, strong) NSArray<BLEPeripheral *> *devices;

@end

@implementation SBViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	
    self.bleManager = [BLEManager sharedInstance];
    
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.tableFooterView = [UIView new];
    
    _right = [[UIBarButtonItem alloc]
              initWithTitle:@"Scan"
              style:UIBarButtonItemStylePlain
              target:self
              action:@selector(scanDidTap:)];
    
    self.navigationItem.rightBarButtonItem = _right;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self addObserver:self forKeyPath:@"scanning" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self removeObserver:self forKeyPath:@"scanning"];
    
    [super viewWillDisappear:animated];
}

- (void)scanDidTap:(id)sender {
    if (self.scanning) {
        [_bleManager stopScan];
        self.scanning = NO;
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
    
    [_bleManager reset];
    
    self.scanning = YES;
    __weak typeof(self) weakself = self;
    [_bleManager scanPeripheralWithUUIDs:nil resultCallback:^(NSDictionary *devices, NSError *error) {
        __strong typeof(weakself) strongself = weakself;
        NSMutableArray *devs = [NSMutableArray array];
        [devices enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            [devs addObject:obj];
        }];
        
        strongself.devices = devs;
        dispatch_async(dispatch_get_main_queue(), ^{
            [strongself.tableView reloadData];
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
    return 90.0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"cell"];
    }
    
    BLEPeripheral *peripheral = [self.devices objectAtIndex:indexPath.row];
    
    cell.textLabel.text = peripheral.peripheral.name;
    
    return cell;
}

@end
