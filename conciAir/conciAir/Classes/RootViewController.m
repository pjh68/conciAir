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
#import "SFIdentityData.h"
#import <QuartzCore/QuartzCore.h>

uint const BEACON_MAJOR = 52231;

@interface RootViewController () <ESTBeaconManagerDelegate>

@property (nonatomic, strong) ESTBeaconManager* beaconManager;
@property (nonatomic, strong) ESTBeacon* selectedBeacon;

@property (nonatomic) UIBackgroundTaskIdentifier bgTask;

@property (strong, nonatomic) CLLocationManager *locationManager;

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
    
    if(self.locationManager==nil){
        _locationManager=[[CLLocationManager alloc] init];
        //I'm using ARC with this project so no need to release
        
        _locationManager.delegate=self;
        _locationManager.purpose = @"We will try to tell you where you are if you get lost";
        _locationManager.desiredAccuracy=kCLLocationAccuracyBest;
        _locationManager.distanceFilter=500;
        self.locationManager=_locationManager;
    }
    
    if([CLLocationManager locationServicesEnabled]){
        [self.locationManager startUpdatingLocation];
    }
    
    /////////////////////////////////////////////////////////////
    // setup Estimote beacon manager
    
    // craete manager instance
    self.beaconManager = [[ESTBeaconManager alloc] init];
    self.beaconManager.delegate = self;
    self.beaconManager.avoidUnknownStateBeacons = YES;
    
    // create sample region with major value defined
    ESTBeaconRegion* region = [[ESTBeaconRegion alloc] initRegionWithMajor:BEACON_MAJOR identifier: @"EstimoteSampleRegion"];
    
    [self.beaconManager requestStateForRegion:region];
}


-(void)beaconManager:(ESTBeaconManager *)manager monitoringDidFailForRegion:(ESTBeaconRegion *)region withError:(NSError *)error {
    
    UIAlertView *alertError=[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to discover beacon in region: %@", error] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertError show];
}

-(void)beaconManager:(ESTBeaconManager *)manager
   didDetermineState:(CLRegionState)state
           forRegion:(ESTBeaconRegion *)region
{
    if(state == CLRegionStateInside)
    {
        // start looking for estimote beacons in region
        [self.beaconManager startRangingBeaconsInRegion:region];
    }
    
    // start looking for estimote beacons in region
    // when beacon ranged beaconManager:didEnterRegion:
    // and beaconManager:didExitRegion: invoked
    [self.beaconManager startMonitoringForRegion:region];
    
}

-(void)beaconManager:(ESTBeaconManager *)manager
      didEnterRegion:(ESTBeaconRegion *)region
{
    // start looking for estimote beacons in region
    [self.beaconManager startRangingBeaconsInRegion:region];

    // present local notification
    NSString *userName = [SFAccountManager sharedInstance].idData.firstName;
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = [NSString stringWithFormat:@"Welcome back %@, swipe for service", userName];
    notification.soundName = UILocalNotificationDefaultSoundName;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
}

-(void)beaconManager:(ESTBeaconManager *)manager
       didExitRegion:(ESTBeaconRegion *)region
{
    [self.beaconManager stopRangingBeaconsInRegion:region];
}


-(void)beaconManager:(ESTBeaconManager *)manager
     didRangeBeacons:(NSArray *)beacons
            inRegion:(ESTBeaconRegion *)region
{
    if([beacons count] > 0)
    {
        self.selectedBeacon = [beacons objectAtIndex:0];
    }
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
    self.helpLabel.text = @"Requesting assistance...";
    
     
    //Animate bell ring
    CAKeyframeAnimation * anim = [ CAKeyframeAnimation animationWithKeyPath:@"transform" ] ;
    anim.values = @[ [ NSValue valueWithCATransform3D:CATransform3DMakeTranslation(-5.0f, 0.0f, 0.0f) ], [ NSValue valueWithCATransform3D:CATransform3DMakeTranslation(5.0f, 0.0f, 0.0f) ] ] ;
    anim.autoreverses = YES ;
    anim.repeatCount = 5.0f ;
    anim.duration = 0.07f ;
    
    [self.bellTop.layer addAnimation:anim forKey:nil ] ;
    
    
    //Make case
    [self sendCreateCaseRequest];
}

/**
 
 */
-(void) sendCreateCaseRequest {
    NSLog(@"sendCreateCaseRequest >>");
    
    SFRestRequest *request;

    NSMutableDictionary *createData = [[NSMutableDictionary alloc] init];
    [createData setValue:[SFAccountManager sharedInstance].credentials.userId forKey:@"userId"];
    
    if (self.selectedBeacon != nil) {
        [createData setValue:[self.selectedBeacon.ibeacon.major stringValue] forKey:@"major"];
        [createData setValue:[self.selectedBeacon.ibeacon.minor stringValue] forKey:@"minor"];
        [createData setValue:[self getProximityString:self.selectedBeacon] forKey:@"proximity"];
    } else {
        [createData setValue:@"-1" forKey:@"major"];
        [createData setValue:@"-1" forKey:@"minor"];
        [createData setValue:@"Unknown" forKey:@"proximity"];
    }
    
    NSString *webserviceEndPoint = @"/services/apexrest/";
    NSString *webservicePath = @"v1.0/conciairPing";
    request = [SFRestRequest requestWithMethod:SFRestMethodPOST path:webservicePath queryParams:createData];
    request.endpoint = webserviceEndPoint;
    
    NSLog(@"Craete Request");
    NSLog(@"Create Data: %@", createData);
    
    [[SFRestAPI sharedInstance] sendRESTRequest:request
                                      failBlock:^(NSError *e) {
                                          NSLog(@"Failed to send create request: %@", e);
                                          self.helpLabel.text = @"Couldn't connect. Try again?";
                                          
                                          UIAlertView *error=[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to send create request: %@", e] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                          [error show];
                                      }
                                  completeBlock:^(NSDictionary *results) {
                                      NSLog(@"Success sending create request");
                                      
                                      self.helpLabel.text = @"Assistance is on it's way";
                                      /*
                                      UIAlertView *success=[[UIAlertView alloc] initWithTitle:@"Success" message:[ NSString stringWithFormat:@"Success: %@", results] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                                      [success show];
                                    */
                                  }
     ];

}

/**
 Format the proxmity of the closest becaon to readable string.
 */
-(NSString *) getProximityString:(ESTBeacon*) becaon {
    
    NSString* proximityString;
    
    // calculate and set new y position
    switch (becaon.ibeacon.proximity)
    {
        case CLProximityUnknown:
            proximityString = @"Unknown";
            break;
        case CLProximityImmediate:
            proximityString = @"Immediate";
            break;
        case CLProximityNear:
            proximityString = @"Near";
            break;
        case CLProximityFar:
            proximityString = @"Far";
            break;
            
        default:
            break;
    }
    
    return proximityString;

}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
    self.bgTask = [application beginBackgroundTaskWithExpirationHandler:^{
        // Clean up any unfinished task business by marking where you
        // stopped or ending the task outright.
        [application endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    }];
    
    // Start the long-running task and return immediately.
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Do the work associated with the task, preferably in chunks.
        
        [application endBackgroundTask:self.bgTask];
        self.bgTask = UIBackgroundTaskInvalid;
    });
}


@end
