#import <Foundation/Foundation.h>

// Admob stuff
#ifdef ADMOB
#import <GoogleMobileAds/GoogleMobileAds.h>
#import <GoogleMobileAds/GADInterstitialDelegate.h>

#include <StoreKit/StoreKit.h>

#include <allegro5/allegro.h>
#include <allegro5/allegro_iphone.h>
#include <allegro5/allegro_iphone_objc.h>

#include "Reachability.h"

#include "apple.h"

static ALLEGRO_DISPLAY *allegro_display;
static volatile int queried_purchased = -1;
static volatile int pay_purchased = -1;
static volatile int purchased = -1;
static volatile bool really_checking_purchase = false;

static GADInterstitial *interstitial;
static int count = 0;

void requestNewInterstitial();

@interface Ad_Delegate : NSObject<GADInterstitialDelegate>
{
}
- (void)interstitialWillDismissScreen:(nonnull GADInterstitial *)ad;
@end

@implementation Ad_Delegate
- (void)interstitialWillDismissScreen:(nonnull GADInterstitial *)ad
{
	requestNewInterstitial();
}
@end

static void *request_thread(void *arg)
{
	al_rest(5.0);
	Ad_Delegate *ad_delegate = [[Ad_Delegate alloc] init];
	interstitial = [[GADInterstitial alloc] initWithAdUnitID:@"ca-app-pub-5564002345241286/1715397850"];
	interstitial.delegate = ad_delegate;
	GADRequest *request = [GADRequest request];
	// Request test ads on devices you specify. Your test device ID is printed to the console when
	// an ad request is made.
	//request.testDevices = @[ kGADSimulatorID, @"FIXME-FOR-TESTING" ];
	[interstitial loadRequest:request];
	return NULL;
}

void requestNewInterstitial()
{
	al_run_detached_thread(request_thread, NULL);
}

void showAd()
{
	ALLEGRO_DISPLAY *display = al_get_current_display();

	[[NSOperationQueue mainQueue] addOperationWithBlock:^{
		if (interstitial.isReady) {
			[interstitial presentFromRootViewController:al_iphone_get_window(display).rootViewController];
			count = 0;
		}
		else {
			count++;
			if (count >= 3) {
				requestNewInterstitial();
				count = 0;
			}
		}
	}];
}

void do_alert(NSString *msg)
{
	UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Alert"
	message:msg
	preferredStyle:UIAlertControllerStyleAlert];

	UIAlertAction* defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
	handler:^(UIAlertAction * action) {}];

	[alert addAction:defaultAction];
	[[al_iphone_get_window(allegro_display) rootViewController] presentViewController:alert animated:YES completion:nil];
}

@interface TransactionObserver<SKPaymentTransactionObserver> : NSObject
{
}
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error;
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue;
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions;
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions;
@end

@implementation TransactionObserver
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
	queried_purchased = 0;
}
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
	NSArray<SKPaymentTransaction *> *transactions = [queue transactions];
    if ([transactions count] == 0) {
        queried_purchased = 0;
        return;
    }
	for (int i = 0; i < [transactions count]; i++) {
		SKPaymentTransaction *t = [transactions objectAtIndex:i];
		if ([[[t payment] productIdentifier] isEqual:@"m2noads"]) {
			if ([t transactionState] == SKPaymentTransactionStatePurchased || [t transactionState] == SKPaymentTransactionStateRestored) {
				queried_purchased = 1;
			}
			else if ([t transactionState] == SKPaymentTransactionStateFailed) {
				queried_purchased = 0;
			}
			// else, wait for the final verdict
		}
	}
}
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions;
{
	for (int i = 0; i < [transactions count]; i++) {
		SKPaymentTransaction *t = [transactions objectAtIndex:i];
		if ([[[t payment] productIdentifier] isEqual:@"m2noads"]) {
			if ([t transactionState] == SKPaymentTransactionStatePurchased || [t transactionState] == SKPaymentTransactionStateRestored) {
				pay_purchased = 1;
				[[SKPaymentQueue defaultQueue] finishTransaction:t];
			}
			else if ([t transactionState] == SKPaymentTransactionStateFailed) {
				NSLog([[t error] domain]);
				printf("%d\n", [[t error] code]);
				do_alert([[t error] localizedDescription]);
				pay_purchased = 0;
				NSLog(@"Transaction failed!");
				[[SKPaymentQueue defaultQueue] finishTransaction:t];
			}
			// else, wait for the final verdict
		}
		else {
			if ([t transactionState] == SKPaymentTransactionStatePurchased || [t transactionState] == SKPaymentTransactionStateRestored || [t transactionState] == SKPaymentTransactionStateFailed) {
				[[SKPaymentQueue defaultQueue] finishTransaction:t];
			}
		}
	}
}
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
}
@end

@interface ProductRequestDelegate<SKProductsRequestDelegate> : NSObject
{
}
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response;
@end

static TransactionObserver<SKPaymentTransactionObserver> *observer;

@implementation ProductRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response;
{
	if ([[response invalidProductIdentifiers] count] > 0) {
		do_alert(@"Invalid product identifier");
        NSLog(@"Invalid product identifier!");
		pay_purchased = 0;
		return;
	}
	for (int i = 0; i < [[response products] count]; i++) {
		SKProduct *p = [[response products] objectAtIndex:i];
		if ([[p productIdentifier] isEqual:@"m2noads"]) {
			if (pay_purchased == -1) {
				SKPayment *payment = [SKPayment paymentWithProduct:p];
				if (observer == NULL) {
					observer = [[TransactionObserver<SKPaymentTransactionObserver> alloc] init];
					[[SKPaymentQueue defaultQueue] addTransactionObserver:observer];
				}
				[[SKPaymentQueue defaultQueue] addPayment:payment];
				return;
			}
		}
		else {
            NSLog(@"Unknown product identifier!");
			pay_purchased = 0;
		}
	}
    NSLog(@"No products!");
	pay_purchased = 0;
}
@end

void queryPurchased()
{
}

static void queryPurchased_real()
{
	queried_purchased = -1;
	if (observer == NULL) {
		observer = [[TransactionObserver<SKPaymentTransactionObserver> alloc] init];
		[[SKPaymentQueue defaultQueue] addTransactionObserver:observer];
	}
	[[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

static ProductRequestDelegate<SKProductsRequestDelegate> *my_delegate;

void restore_purchases()
{
	queryPurchased_real();
	while (queried_purchased == -1); // wait
	if (queried_purchased == 1) {
		purchased = 1;
		really_checking_purchase = true;
		return;
	}
}

void doIAP()
{
	allegro_display = al_get_current_display();

	Reachability *networkReachability = [Reachability reachabilityForInternetConnection];   
	NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];    
	if (networkStatus == NotReachable) {        
		show_please_connect_dialog(false);
		return;
	}

	restore_purchases();

	if (purchased == 1) {
		return;
	}

	pay_purchased = -1;
	NSArray *products_a = @[@"m2noads"];
	NSSet *products = [NSSet setWithArray:products_a];
	SKProductsRequest *request = [[SKProductsRequest alloc] initWithProductIdentifiers:products];
	my_delegate = [[ProductRequestDelegate<SKProductsRequestDelegate> alloc] init];
	request.delegate = my_delegate;
	[request start];
	while (pay_purchased == -1); // wait
	purchased = pay_purchased;
	if (pay_purchased == 1) {
		really_checking_purchase = true;
	}
}

int checkPurchased()
{
	return isPurchased();
}

int isPurchased()
{
	if (really_checking_purchase) {
		return purchased;
	}
	else {
		return isPurchased_engine();
	}
}
#endif // ADMOB

// localization

const char *get_apple_language()
{
	static char buf[100];

    NSString *str = [[NSLocale preferredLanguages] objectAtIndex:0];
    
	if ([str hasPrefix:@"de"]) {
		strcpy(buf, "german");
	}
	else if ([str hasPrefix:@"fr"]) {
		strcpy(buf, "french");
	}
	else if ([str hasPrefix:@"nl"]) {
		strcpy(buf, "dutch");
	}
	else if ([str hasPrefix:@"el"]) {
		strcpy(buf, "greek");
	}
	else if ([str hasPrefix:@"it"]) {
		strcpy(buf, "italian");
	}
	else if ([str hasPrefix:@"pl"]) {
		strcpy(buf, "polish");
	}
	else if ([str hasPrefix:@"pt"]) {
		strcpy(buf, "portuguese");
	}
	else if ([str hasPrefix:@"ru"]) {
		strcpy(buf, "russian");
	}
	else if ([str hasPrefix:@"es"]) {
		strcpy(buf, "spanish");
	}
	else if ([str hasPrefix:@"ko"]) {
		strcpy(buf, "korean");
	}
	else {
		strcpy(buf, "english");
	}

	return buf;
}
