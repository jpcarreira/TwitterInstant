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
    [[[[[self requestAccessToTwitterSignal]
      
        // chaining
        // (the application need to wait for the signal that requests access to twitter to emit
        // its completed event and then subscribe the next text field's signal)
        // (the then method waits until a completed event is emitted and then subscribes to the signal returned
        // by its block parameter, thus effectively passing control from one signal to the next; error events
        // are also passed through)
        then:^RACSignal*{
            return self.searchText.rac_textSignal;
        }]
     
        // adding a filter to the pipeline to remove invalid search strings (<3 chars)
        filter:^BOOL(NSString *text){
            return [self isValidSearchText:text];
        }]
     
        // subscribing to the signal for search twitter with a flatten map
        flattenMap:^RACStream *(NSString *text)
        {
            return [self signalForSearchWithText:text];
        }]
     
        subscribeNext:^(id x)
        {
            NSLog(@"%@", x);
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


// creating a signal based on the SLRequest
-(RACSignal *)signalForSearchWithText:(NSString *)text
{
    // defining the errors
    // (one if the user hasn't add any twitter accounts to their device and another for query-related errors)
    NSError *noAccountsError = [NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterInstantErrorNoTwitterAccounts userInfo:nil];
    NSError *invalidResponseError = [NSError errorWithDomain:RWTwitterInstantDomain code:RWTwitterInstantErrorInvalidResponse userInfo:nil];
    
    // creating the signal block
    @weakify(self)
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber){
        @strongify(self);
        
        // creating the request for the given search string using the method indicated
        SLRequest *request = [self requestForTwitterSearchWithText:text];
        
        // supplying a twitter account
        // (querrying the account store for the first available twitter account)
        NSArray *twitterAccounts = [self.accountStore accountsWithAccountType:self.twitterAccountType];
        
        if(twitterAccounts.count == 0)
        {
            [subscriber sendError:noAccountsError];
        }
        else
        {
            [request setAccount:[twitterAccounts lastObject]];
            
            // performing the request
            [request performRequestWithHandler:^(NSData *responseData, NSHTTPURLResponse *urlResponse, NSError *error){
                
                // if successfull, we'll parse the response
                // (the JSON data is parsed and emitted along as a next event followed by a completed event)
               if(urlResponse.statusCode == 200)
               {
                   NSDictionary *timelineData = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:nil];
                   [subscriber sendNext:timelineData];
                   [subscriber sendCompleted];
               }
                
                // sending error on failure
                else
                {
                    [subscriber sendError:invalidResponseError];
                }
            }];
        }
        return nil;
    }];
}



#pragma mark - auxiliary methods

// validating the search text to have at least 2 characters
-(BOOL)isValidSearchText:(NSString *)text
{
    return text.length > 2;
}


// creating a request that searches twitter via the v1.1 REST API
// (uses the q search parameter to search for tweets that contain the given search string)
-(SLRequest *)requestForTwitterSearchWithText:(NSString *)text
{
    NSURL *url = [NSURL URLWithString:@"https://api.twitter.com/1.1/search/tweets.json"];
    
    NSDictionary *params = @{@"q" : text};
    
    SLRequest *request = [SLRequest requestForServiceType:SLServiceTypeTwitter requestMethod:SLRequestMethodGET URL:url parameters:params];
    
    return request;
}

@end
