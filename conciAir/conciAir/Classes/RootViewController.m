//
//  RootViewController.m
//  conciAir
//
//  Created by Matthew Prechner on 18/11/2013.
//  Copyright (c) 2013 Deloitte. All rights reserved.
//

#import "RootViewController.h"
#import "SFRestRequest.h"
#import "SFRestAPI+Blocks.h"
#import "SFAccountManager.h"
#import <ESTBeaconManager.h>

@interface RootViewController () <ESTBeaconManagerDelegate>

@property (nonatomic, strong) ESTBeaconManager* beaconManager;
@property (nonatomic, strong) ESTBeacon* selectedBeacon;

@end

@implementation RootViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 Handler User Click HELP
 */
-(IBAction) onClickHelp:(id) sender {
    NSLog(@"onClickHelp >>");
    
    [self sendCreateCaseRequest];
}

/**
 
 */
-(void) sendCreateCaseRequest {
    NSLog(@"sendCreateCaseRequest >>");
    
    SFRestRequest *request;

    NSMutableDictionary *createData = [[NSMutableDictionary alloc] init];
    [createData setValue:[SFAccountManager sharedInstance].credentials.userId forKey:@"userId"];

    NSString *webserviceEndPoint = @"/services/apexrest/<< SERVICE URL GOES HERE >>";
    NSString *webservicePath = @"<< WEBSERIVICE VERSION >>/<< WEB SERVICE PATH >>";
    request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:webservicePath queryParams:createData];
    request.endpoint = [webserviceEndPoint stringByAppendingString: @"/"];
    
    NSLog(@"Craete Request");
    NSLog(@"Create Data: %@", createData);
    
    [[SFRestAPI sharedInstance] sendRESTRequest:request
                                      failBlock:^(NSError *e) {
                                          NSLog(@"Failed to send create request: %@", e);
                                          
                                          UIAlertView *error=[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to send create request: %@", e] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                          [error show];
                                      }
                                  completeBlock:^(NSDictionary *results) {
                                      NSLog(@"Success sending create request");
                                      
                                      UIAlertView *success=[[UIAlertView alloc] initWithTitle:@"Success" message:@"Success" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                      [success show];
                                  }
     ];

}


@end
