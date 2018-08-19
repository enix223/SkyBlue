//
//  SBDetailController.h
//  SkyBlue_Example
//
//  Created by Enix Yu on 19/8/2018.
//  Copyright © 2018 enix223. All rights reserved.
//

#import <UIKit/UIKit.h>

@class BLEPeripheral;

@interface SBDetailController : UIViewController

@property (weak, nonatomic) IBOutlet UITableView *tableView;

@property (nonatomic, strong) BLEPeripheral *peripheral;

@end
