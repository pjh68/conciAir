//
//  RootViewController.h
//  conciAir
//
//  Created by Matthew Prechner on 18/11/2013.
//  Copyright (c) 2013 Deloitte. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RootViewController : UIViewController

@property (strong, nonatomic) IBOutlet UIButton *helpBtn;
@property (strong, nonatomic) IBOutlet UILabel *helpLabel;
@property (strong, nonatomic) IBOutlet UIView *bellTop;

-(IBAction) onClickHelp:(id) sender;



@end
