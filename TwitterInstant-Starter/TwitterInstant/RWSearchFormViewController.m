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

@interface RWSearchFormViewController ()

@property (weak, nonatomic) IBOutlet UITextField *searchText;

@property (strong, nonatomic) RWSearchResultsViewController *resultsViewController;

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
    [[self.searchText.rac_textSignal map:^id(NSString *text){
        return [self isValidSearchText:text] ? [UIColor whiteColor] : [UIColor yellowColor];
    }]
    subscribeNext:^(UIColor *color){
        self.searchText.backgroundColor = color;
    }];
}


#pragma mark - auxiliary methods

// validating the search text to have at least 2 characters
-(BOOL)isValidSearchText:(NSString *)text
{
    return text.length > 2;
}

@end
