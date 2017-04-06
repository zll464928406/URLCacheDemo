//
//  ViewController.m
//  Test
//
//  Created by sunny on 17/4/6.
//  Copyright © 2017年 sunny. All rights reserved.
//

#import "ViewController.h"
#import "MXURLCache.h"

@interface ViewController ()<UIWebViewDelegate>
@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    MXURLCache *urlCache = [[MXURLCache alloc] initWithMemoryCapacity:20 * 1024 * 1024
                                                         diskCapacity:200 * 1024 * 1024
                                                             diskPath:nil
                                                            cacheTime:0];
    [MXURLCache setSharedURLCache:urlCache];
    
    self.webView.delegate = self;
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.moxtra.com/service3/#/timeline"]]];
}

#pragma mark - User Action
- (IBAction)tapped:(id)sender
{
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://www.moxtra.com/service3/#/timeline"]]];
}

#pragma mark - UIWebViewDelegate

@end
