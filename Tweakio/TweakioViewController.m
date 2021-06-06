#import "TweakioViewController.h"
#import "TweakViewController.h"
#import "TweakioResultsViewController.h"
#import "Settings.h"
#import "UITableViewCell+CydiaLike.h"
#define preferencesPath @"/var/mobile/Library/Preferences/com.spartacus.tweakioprefs.plist"
#define bundlePath @"/Library/MobileSubstrate/DynamicLibraries/com.spartacus.tweakio.bundle"


@interface TweakioViewController ()

@property (nonatomic, strong) NSArray<Result *> *results;
@property (nonatomic, strong) UISearchController *searchController;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (assign) int preferredAPI;

@end

@implementation TweakioViewController

- (instancetype)initWithPackageManager:(NSString *)packageManager {
    self = [super init];
    if (self) {
        self.packageManager = packageManager;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:[[TweakioResultsViewController alloc] initWithNavigationController:self.navigationController andPackageManager:self.packageManager]];
    [self.searchController setObscuresBackgroundDuringPresentation:NO];
    [self.searchController setSearchResultsUpdater:self];
    [self.searchController.searchBar setDelegate:self];
    [self.searchController.searchBar setPlaceholder:@"Search Packages"];
    [self.navigationItem setSearchController:self.searchController];
    [self.navigationItem setHidesSearchBarWhenScrolling:NO];

    [self setTitle:@"Tweakio"];
    
    if (@available(iOS 13, *))
        self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    else
        self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.activityIndicator setCenter:self.view.center];
    [self.view addSubview:self.activityIndicator];

    
    self.results = [NSArray array];

    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:preferencesPath];
    NSNumber *hookingMethod = (NSNumber *)[prefs objectForKey:[NSString stringWithFormat:@"%@ hooking method", self.packageManager.lowercaseString]];

    if (hookingMethod && hookingMethod.intValue == 1) {
        UIBarButtonItem *tweakio = [[UIBarButtonItem alloc] initWithTitle:@"Default" style:UIBarButtonItemStylePlain target:self action:@selector(goBack:)];
        [self.navigationItem setLeftBarButtonItem:tweakio];
    }

    UIBarButtonItem *settings = [[UIBarButtonItem alloc] initWithTitle:@"Settings" style:UIBarButtonItemStylePlain target:self action:@selector(openSettings:)];
    [self.navigationItem setRightBarButtonItem:settings];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [self.view setBackgroundColor:self.backgroundColor];

    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:preferencesPath];
    self.preferredAPI = ((NSNumber *)prefs[[NSString stringWithFormat:@"%@ API", self.packageManager]]).intValue;
}

- (void)goBack:(UIBarButtonItem *)sender {
	NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:preferencesPath];
	NSNumber *animation = [prefs objectForKey:[NSString stringWithFormat:@"%@ animation", self.packageManager.lowercaseString]];

	if (animation && !animation.boolValue) {
		[self.navigationController popViewControllerAnimated:NO];
		return;
	}

    CATransition *transition = [[CATransition alloc] init];
    [transition setDuration:0.3];
    [transition setType:@"flip"];
    [transition setSubtype:kCATransitionFromRight];
    [self.navigationController.view.layer addAnimation:transition forKey:kCATransition];
    [self.navigationController popViewControllerAnimated:NO];
    
}

- (void)openSettings:(UIBarButtonItem *)sender {
   [self.navigationController pushViewController:[[Settings alloc] initWithPackageManager:self.packageManager andBackgroundColor:self.view.backgroundColor] animated:YES];
}

- (void)search:(NSString *)query {
    switch (self.preferredAPI) {
        case 0:
            @try {
                self.results = spartacusAPI(query);
            } @catch (NSException *exception) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"An error has occurred" message:@"Please try again later or change API." preferredStyle:UIAlertControllerStyleAlert];
                    [self presentViewController:alert animated:YES completion:^{
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [alert dismissViewControllerAnimated:YES completion:NULL];
                        });
                    }];
                });
                self.results = [NSArray array];
            }
            break;
        case 1:
            @try {
                self.results = parcilityAPI(query);
            } @catch (NSException *exception) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"An error has occurred" message:@"Please try again later or change API." preferredStyle:UIAlertControllerStyleAlert];
                    [self presentViewController:alert animated:YES completion:^{
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [alert dismissViewControllerAnimated:YES completion:NULL];
                        });
                    }];
                });
                self.results = [NSArray array];
            }
            break;
        case 2:
            @try {
                self.results = canisterAPI(query);
            } @catch (NSException *exception) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"An error has occurred" message:@"Please try again later or change API." preferredStyle:UIAlertControllerStyleAlert];
                    [self presentViewController:alert animated:YES completion:^{
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            [alert dismissViewControllerAnimated:YES completion:NULL];
                        });
                    }];
                });
                self.results = [NSArray array];
            }
            break;
        default:  // How did we get here?
            self.results = [NSArray array];
            break;
    }
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar endEditing:YES];
    NSString *tweak = searchBar.text;
    if ([tweak isEqualToString:@""]) {
        self.results = [NSArray array];
        return;
    }
    
    [self.activityIndicator startAnimating];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self search:tweak];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.activityIndicator stopAnimating];
            
            [((TweakioResultsViewController *)self.searchController.searchResultsController) setupWithResults:self.results andBackgroundColor:self.backgroundColor];
        });
    });
}

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    if ([searchController.searchBar.text isEqualToString:@""]) {
        self.results = [NSArray array];
    }
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if ([searchBar.text isEqualToString:@""]) {
        [((TweakioResultsViewController *)self.searchController.searchResultsController) clear];
        self.results = [NSArray array];
    }
}

@end

NSArray<Result *> *spartacusAPI(NSString *query) {
    query = [query stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
    NSURL *api = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"https://spartacusdev.herokuapp.com/api/search/%@", query]];
    NSData *data = [NSData dataWithContentsOfURL:api];
    if (!data) {
        @throw [[NSException alloc] initWithName:@"APIException" reason:@"UNKNOWN" userInfo:nil];
        return [NSArray array];
    }
    NSDictionary *results = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:NULL];
    NSMutableArray *resultsArray = [NSMutableArray array];

    for (NSDictionary *result in results[@"data"]) {
        NSObject *icon;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.png", bundlePath, result[@"section"]]])
            icon = [UIImage imageWithData:[NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.png", bundlePath, result[@"section"]]]];
        else
            icon = [UIImage imageWithData:[NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/unknown.png", bundlePath]]];
        
        NSString *iconURL;
        if ([result[@"icon"] isEqualToString:@""] || [result[@"icon"] hasPrefix:@"file://"] || ((NSObject *)results[@"icon"]).class == NSNull.class) {
            iconURL = [NSString stringWithFormat:@"%@/%@.png", bundlePath, result[@"section"]];
            if (![[NSFileManager defaultManager] fileExistsAtPath:iconURL])
                iconURL = [NSString stringWithFormat:@"%@/unknown.png", bundlePath];
        }
        else
            iconURL = result[@"icon"];
        
        NSDictionary *data = @{
            @"name": result[@"name"],
            @"package": result[@"package"],
            @"version": result[@"version"],
            @"description": result[@"description"],
            @"author": result[@"author"],
            @"icon": icon,
            @"filename": [NSURL URLWithString:result[@"filename"]],
            @"free": result[@"free"],
            @"repo": [[Repo alloc] initWithURL:[NSURL URLWithString:result[@"repo"]] andName:result[@"repo name"]],
            @"icon url": [iconURL hasPrefix:@"http"] ? [NSURL URLWithString:iconURL] : [NSURL fileURLWithPath:iconURL],
            @"depiction": [result objectForKey:@"depiction"] ? [NSURL URLWithString:result[@"depiction"]] : [NSURL URLWithString:@""],
            @"section": result[@"section"],
        };
        [resultsArray addObject:[[Result alloc] initWithDictionary:data]];
    }
    return [resultsArray copy];
}

NSArray<Result *> *parcilityAPI(NSString *query) {
    query = [query stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
    NSURL *api = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"https://api.parcility.co/db/search?q=%@", query]];
    NSData *data = [NSData dataWithContentsOfURL:api];
    NSDictionary *results = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:NULL];
    if (!data) {
        @throw [[NSException alloc] initWithName:@"APIException" reason:@"UNKNOWN" userInfo:nil];
        return [NSArray array];
    }
    NSMutableArray *resultsArray = [NSMutableArray array];

    for (NSDictionary *result in results[@"data"]) {
        NSObject *icon;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.png", bundlePath, result[@"Section"]]])
            icon = [UIImage imageWithData:[NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.png", bundlePath, result[@"Section"]]]];
        else
            icon = [UIImage imageWithData:[NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/unknown.png", bundlePath]]];

        NSString *iconURL;
        if ([result[@"Icon"] isEqualToString:@""] || [result[@"Icon"] hasPrefix:@"file://"] || ((NSObject *)results[@"Icon"]).class == NSNull.class) {
            iconURL = [NSString stringWithFormat:@"%@/%@.png", bundlePath, result[@"Section"]];
            if (![[NSFileManager defaultManager] fileExistsAtPath:iconURL])
                iconURL = [NSString stringWithFormat:@"%@/unknown.png", bundlePath];
        }
        else
            iconURL = result[@"Icon"];
        
        NSDictionary *data = @{
            @"name": result[@"Name"],
            @"package": result[@"Package"],
            @"version": result[@"Version"],
            @"description": result[@"Description"],
            @"author": result[@"Author"],
            @"icon": icon,
            @"filename": [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", result[@"repo"][@"url"], ((NSArray *)result[@"builds"]).lastObject[@"Filename"]]],
            @"free": [NSNumber numberWithBool:[[results[@"Tag"] componentsSeparatedByString:@", "] containsObject:@"cydia::commercial"]],
            @"repo": [[Repo alloc] initWithURL:[NSURL URLWithString:result[@"repo"][@"url"]] andName:result[@"repo"][@"label"]],
            @"icon url": [iconURL hasPrefix:@"http"] ? [NSURL URLWithString:iconURL] : [NSURL fileURLWithPath:iconURL],
            @"depiction": [result objectForKey:@"Depiction"] ? [NSURL URLWithString:result[@"Depiction"]] : [NSURL URLWithString:@""],
            @"section": result[@"Section"],
        };
        [resultsArray addObject:[[Result alloc] initWithDictionary:data]];
    }
    return [resultsArray copy];
}

NSArray<Result *> *canisterAPI(NSString *query) {
    query = [query stringByReplacingOccurrencesOfString:@" " withString:@"%20"];
    NSURL *api = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"https://api.canister.me/v1/community/packages/search?query=%@&searchFields=identifier,name,author,maintainer&responseFields=identifier,name,description,packageIcon,repository.uri,repository.name,author,latestVersion,depiction,section,price", query]];
    NSData *data = [NSData dataWithContentsOfURL:api];
    if (!data) {
        @throw [[NSException alloc] initWithName:@"APIException" reason:@"UNKNOWN" userInfo:nil];
        return [NSArray array];
    }
    NSDictionary *results = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:NULL];
    NSMutableArray *resultsArray = [NSMutableArray array];

    for (NSDictionary *result in results[@"data"]) {
        NSObject *icon;
        if ([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@.png", bundlePath, result[@"section"]]])
            icon = [UIImage imageWithData:[NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/%@.png", bundlePath, result[@"section"]]]];
        else
            icon = [UIImage imageWithData:[NSData dataWithContentsOfFile:[NSString stringWithFormat:@"%@/unknown.png", bundlePath]]];

        NSString *iconURL;
        if ([result[@"packageIcon"] isEqualToString:@""] || [result[@"packageIcon"] hasPrefix:@"file://"] || ((NSObject *)results[@"packageIcon"]).class == NSNull.class) {
            iconURL = [NSString stringWithFormat:@"%@/%@.png", bundlePath, result[@"section"]];
            if (![[NSFileManager defaultManager] fileExistsAtPath:iconURL])
                iconURL = [NSString stringWithFormat:@"%@/unknown.png", bundlePath];
        }
        else
            iconURL = result[@"packageIcon"];

        NSDictionary *data = @{
            @"name": result[@"name"],
            @"package": result[@"identifier"],
            @"version": result[@"latestVersion"],
            @"description": result[@"description"],
            @"author": result[@"author"],
            @"icon": icon,
            @"price": result[@"price"],
            @"repo": [[Repo alloc] initWithURL:[NSURL URLWithString:result[@"repository"][@"uri"]] andName:result[@"repository"][@"name"]],
            @"icon url": [iconURL hasPrefix:@"http"] ? [NSURL URLWithString:iconURL] : [NSURL fileURLWithPath:iconURL],
            @"depiction": [result objectForKey:@"depiction"] ? [NSURL URLWithString:result[@"depiction"]] : [NSURL URLWithString:@""],
            @"section": result[@"section"],
        };
        [resultsArray addObject:[[Result alloc] initWithDictionary:data]];
    }
    return [resultsArray copy];
}
