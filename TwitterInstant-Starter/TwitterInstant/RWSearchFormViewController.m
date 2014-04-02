//
//  RWSearchFormViewController.m
//  TwitterInstant
//
//  Created by Colin Eberhardt on 02/12/2013.
//  Copyright (c) 2013 Colin Eberhardt. All rights reserved.
//

#import "RWSearchFormViewController.h"
#import "RWSearchResultsViewController.h"
#import <ReactiveCocoa.h>
#import "RACEXTScope.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>


// enumeration for Twitter connection status
typedef NS_ENUM(NSInteger, RWTwitterInstantError)
{
    RWTwitterInstantErrorAccessDenied,
    RWTwitterInstantErrorNoTwitterAccounts,
    RWTwitterInstantErrorInvalidResponse
};


static NSString * const RWTwitterInstantDomain = @"TwitterInstant";


@interface RWSearchFormViewController ()

@property (weak, nonatomic) IBOutlet UITextField *searchText;

@property (strong, nonatomic) RWSearchResultsViewController *resultsViewController;


// class to access various social media accounts the device can connect to
@property (nonatomic, strong) ACAccountStore *accountStore;

// specific account type
@property (nonatomic, strong) ACAccountType *twitterAccountType;

@end

@implementation RWSearchFormViewController


- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.title = @"Twitter Instant";
  
  [self styleTextField:self.searchText];
  
    // locates the resultsViewController and assigns it to the resultsViewController property
    // the major application logic is going to live within this class so this property will supply search results to RWSearchResultsViewController
  self.resultsViewController = self.splitViewController.viewControllers[1];
  
    // text field background color using RAC
    [self updateTextFieldBackgroundColorIfTextIsValid];
    
    
    // creating the account store and twitter account identifier
    self.accountStore = [[ACAccountStore alloc] init];
    self.twitterAccountType = [self.accountStore accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
    
    // subscribing the RAC signal to get access to the twitter account
    [[self requestAccessToTwitterSignal]
        subscribeNext:^(id x)
        {
            NSLog(@"Access granted!");
        }
        error:^(NSError *error)
        {
            NSLog(@"Error: %@", error);
        }];
    
}


- (void)styleTextField:(UITextField *)textField
{
  CALayer *textFieldLayer = textField.layer;
  textFieldLayer.borderColor = [UIColor grayColor].CGColor;
  textFieldLayer.borderWidth = 2.0f;
  textFieldLayer.cornerRadius = 0.0f;
}


#pragma mark - RAC methods

// takes the search field text, transforms ('maps') it to a UIColor and applies it to text field background color
-(void)updateTextFieldBackgroundColorIfTextIsValid
{
    RACSignal *validSearchTextSignal = [self validSearchTextSignal];
    
    RAC(self.searchText, backgroundColor) =
        [validSearchTextSignal
         map:^(NSNumber *number){
             return [number boolValue] ? [UIColor whiteColor] : [UIColor yellowColor];
         }];
}


// gets a RAC signal from a valid search text field
-(RACSignal *)validSearchTextSignal
{
    return [self.searchText.rac_textSignal
            map:^id(NSString *text){
                return @([self isValidSearchText:text]);
            }];
}


// signal to request access to twitter account
-(RACSignal *)requestAccessToTwitterSignal
{
    // defining an error
    NSError *accessError = [NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterInstantErrorAccessDenied userInfo:nil];
    
    // creating the signal (and returning an instance of RACSignal)
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        // requesting access to Twitter via the account store
        // (at this point the user will see a prompt asking to grant this app access to the twitter account)
        @strongify(self)
        [self.accountStore requestAccessToAccountsWithType:self.twitterAccountType options:nil completion:^(BOOL granted, NSError *error){
           
            // handling the response
            // if access is denied we send a error event
            if(!granted)
            {
                [subscriber sendError:accessError];
            }
            
            // if access is granted we send a next followed by completed
            else
            {
                [subscriber sendNext:nil];
                [subscriber sendCompleted];
            }
        }];
        return nil;
    }];
}


#pragma mark - auxiliary methods

// validating the search text to have at least 2 characters
-(BOOL)isValidSearchText:(NSString *)text
{
    return text.length > 2;
}

@end
