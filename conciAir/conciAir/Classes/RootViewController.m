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

uint const BEACON_MAJOR = 52231;

@interface RootViewController () <ESTBeaconManagerDelegate>

@property (nonatomic, strong) ESTBeaconManager* beaconManager;
@property (nonatomic, strong) ESTBeacon* selectedBeacon;

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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/**
 On view load setup location services and enable beacon searching.
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    /////////////////////////////////////////////////////////////
    // FORCE Location Services Startup
    [self setupLocationServices];
    
    /////////////////////////////////////////////////////////////
    // SETUP Estimote beacon manager
    [self setupEstimoteBeacon];
    
}

/**
 Setup location services, forces the app to register for location updates which
 enables the Estimote bluetooth becaons.
 */
-(void) setupLocationServices {
    
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
}

/////////////////////////////////////////////////////////////
//
#pragma mark - Beacon Manager

/**
 Setup estimote beacons. Initialise the beacon manager and create scanning region
 to search for beacons. Request state of current region to detect if user is
 already within the beacon range and start monitoring for changes to users location.
 */
-(void) setupEstimoteBeacon {
    // craete manager instance
    self.beaconManager = [[ESTBeaconManager alloc] init];
    self.beaconManager.delegate = self;
    self.beaconManager.avoidUnknownStateBeacons = YES;
    
    // create sample region with major value defined
    ESTBeaconRegion* region = [[ESTBeaconRegion alloc] initRegionWithMajor:BEACON_MAJOR identifier: @"EstimoteSampleRegion"];
    
    [self.beaconManager requestStateForRegion:region];
    
    // start looking for estimote beacons in region
    // when beacon ranged beaconManager:didEnterRegion:
    // and beaconManager:didExitRegion: invoked
    [self.beaconManager startMonitoringForRegion:region];
    
}

/**
 Handle scenarios where monitoring fails for the region.
 
 Don't show user an error message, fail silently. User can still make use of
 assistance request.
 
 */
-(void)beaconManager:(ESTBeaconManager *)manager monitoringDidFailForRegion:(ESTBeaconRegion *)region withError:(NSError *)error {
    
    NSLog(@"Failed to discover beacon in region: %@", error);
    
    /*
    UIAlertView *alertError=[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Failed to discover beacon in region: %@", error] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertError show];
     */
}

/**
 When initial state determined if currently in beacon range start searching
 for particular beacon data.
 */
-(void)beaconManager:(ESTBeaconManager *)manager
   didDetermineState:(CLRegionState)state
           forRegion:(ESTBeaconRegion *)region
{
    if(state == CLRegionStateInside)
    {
        // start looking for estimote beacons in region
        [self.beaconManager startRangingBeaconsInRegion:region];
    }
    
}

/**
 Handle beacons coming into range. This means the user has entered the shop area
 and should be presented with a notifcation. Start looking for specific beacon
 data to locate their exact position in the shop.
 */
-(void)beaconManager:(ESTBeaconManager *)manager
      didEnterRegion:(ESTBeaconRegion *)region
{
    // start looking for estimote beacons in region
    [self.beaconManager startRangingBeaconsInRegion:region];

    // present local notification
    NSString *userName = [SFAccountManager sharedInstance].idData.firstName;
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = [NSString stringWithFormat:@"Welcome back %@. conciAir is ready when you are", userName];
    notification.alertAction = [NSString stringWithFormat:@"get help"];
    notification.soundName = UILocalNotificationDefaultSoundName;
    
    [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
}

/**
 Handle beacons exiting range. This means the user has left the shop area, stop
 looking for specific beacon data.
 */
-(void)beaconManager:(ESTBeaconManager *)manager
       didExitRegion:(ESTBeaconRegion *)region
{
    [self.beaconManager stopRangingBeaconsInRegion:region];
}

/**
 Beacon ranging update, store details of closest beacon, this data is used to 
 determine the exact position within the shop.
 */
-(void)beaconManager:(ESTBeaconManager *)manager
     didRangeBeacons:(NSArray *)beacons
            inRegion:(ESTBeaconRegion *)region
{
    if([beacons count] > 0)
    {
        self.selectedBeacon = [beacons objectAtIndex:0];
    }
}

/////////////////////////////////////////////////////////////
//
#pragma mark - Service Request

/**
 Button handler for user clicking help request.
 
 Provide feedback to the user and initiate help case request.
 */
-(IBAction) onClickHelp:(id) sender {
    NSLog(@"onClickHelp >>");
    self.helpLabel.text = @"Requesting assistance...";
    
    [self sendCreateCaseRequest];
}

/**
 Initiate the help request by sending a location notification to Salesforce.
 
 Makes POST request with custom web service providing beacon identification and
 proximity data.
 */
-(void) sendCreateCaseRequest {
    NSLog(@"sendCreateCaseRequest >>");
    
    /////////////////////////////////////////////////////////////
    // Get location data and create post data.
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
    
    /////////////////////////////////////////////////////////////
    // Send request to custom webservice
    SFRestRequest *request;

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

                                      }
                                  completeBlock:^(NSDictionary *results) {
                                      NSLog(@"Success sending create request");
                                      
                                      self.helpLabel.text = @"Assistance is on it's way";
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

@end
