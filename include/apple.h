#ifndef APPLE_H
#define APPLE_H

#ifdef __cplusplus
extern "C" {
#endif

#ifdef ADMOB
void showAd();
void requestNewInterstitial();

int isPurchased();
void queryPurchased();
void doIAP();
int checkPurchased();
void restore_purchases();

int isPurchased_engine();
void show_please_connect_dialog(bool is_network_test);
#endif

const char *get_apple_language();

#ifdef __cplusplus
}
#endif

#endif // APPLE_H
