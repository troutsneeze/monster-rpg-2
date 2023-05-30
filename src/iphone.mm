#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVAudioSession.h>
#import "mygamecentervc.h"

#include <allegro5/allegro.h>
#include <allegro5/allegro_iphone.h>
#include <allegro5/allegro_iphone_objc.h>
#include <allegro5/internal/aintern_keyboard.h>


#define NO_BASS
#include "monster2.hpp"

static ALLEGRO_DISPLAY *allegro_display;

extern bool center_button_pressed;

// return true on success
bool get_clipboard(char *buf, int len)
{
	NSString *d = [[UIPasteboard generalPasteboard] string];
	if (d == nil)
		return false;
	strcpy(buf, [d UTF8String]);
	return true;
}

void set_clipboard(char *buf)
{
	NSData *d = [NSData dataWithBytes:buf length:strlen(buf)];
	[[UIPasteboard generalPasteboard] setData:d forPasteboardType:(NSString *)kUTTypeUTF8PlainText];
}

float getBatteryLevel(void)
{
	// this was removed from Allegro
	return 1.0f;//al_iphone_get_battery_level();
}

bool isMultitaskingSupported(void)
{
	char buf[100];
	strcpy(buf, [[[UIDevice currentDevice] systemVersion] UTF8String]);
	if (atof(buf) < 4.0) return false;
	bool b = [[UIDevice currentDevice] isMultitaskingSupported];
	return b;
}

void vibrate(void)
{
	AudioServicesPlaySystemSound (kSystemSoundID_Vibrate);
}

void disableMic(void)
{
	[[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:NULL];
}

double my_last_shake_time = 0.0;

static UITextView *text_view;
ALLEGRO_EVENT_SOURCE user_event_source;

static void destroy_event(ALLEGRO_USER_EVENT *u)
{
}

const char *downs = "WDXAYUIOHJKL";
const char *ups   = "ECZQTFMGRNPV";

static int event_type(char c, int *index)
{
	int i;

	for (i = 0; downs[i]; i++) {
		if (c == downs[i]) {
			*index = i;
			return USER_KEY_DOWN;
		}
	}

	for (i = 0; ups[i]; i++) {
		if (c == ups[i]) {
			*index = i;
			return USER_KEY_UP;
		}
	}

	return -1;
}

static bool gen_event(ALLEGRO_EVENT *e, char c)
{
	int index;
	int type = event_type(c, &index);
	if (type < 0) {
		return false;
	}

	c = (type == USER_KEY_DOWN) ? c : downs[index];
	c = (c-'A') + ALLEGRO_KEY_A;

	e->user.type = type;
	e->keyboard.keycode = c;

	return true;
}

ALLEGRO_KEYBOARD_STATE icade_keyboard_state;

@interface KBDelegate : NSObject<UITextViewDelegate>
- (void)start;
- (void)switch_in;
- (void)textViewDidChange:(UITextView *)textView;
@end
@implementation KBDelegate
- (void)start
{
	UIWindow *window = al_iphone_get_window(display);

	CGRect r = CGRectMake(0, 0, 0, 0);
	text_view = [[UITextView alloc] initWithFrame:r];
	if ([text_view respondsToSelector: @selector(inputAssistantItem)]) {
		text_view.inputAssistantItem.leadingBarButtonGroups = @[];
		text_view.inputAssistantItem.trailingBarButtonGroups = @[];
	}
	text_view.delegate = self;
	text_view.hidden = YES;
	
	CGRect r2 = CGRectMake(0, 0, 0, 0);
	UIView *blank = [[UIView alloc] initWithFrame:r2];
	blank.hidden = YES;
	
	text_view.inputView = blank;

	[window addSubview:text_view];
	[text_view becomeFirstResponder];
}

- (void)switch_in
{
	[text_view removeFromSuperview];
	UIWindow *window = al_iphone_get_window(display);
	[window addSubview:text_view];
	[text_view becomeFirstResponder];
}

- (void)textViewDidChange:(UITextView *)textView
{
	while ([textView.text length] > 0) {
		NSString *first = [textView.text substringToIndex:1];
		NSString *remain = [textView.text substringFromIndex:1];
		textView.text = remain;
		const char *txt = [first UTF8String];
		ALLEGRO_EVENT *e = (ALLEGRO_EVENT *)malloc(sizeof(ALLEGRO_EVENT));
		ALLEGRO_EVENT *e2 = NULL;
		bool emit = false;
		if (gen_event(e, toupper(txt[0]))) {
			TripleInput *i = getInput();
			if (i) {
				i->handle_event(e);
			}
			if (e->type == USER_KEY_DOWN) {
				e2 = (ALLEGRO_EVENT *)malloc(sizeof(ALLEGRO_EVENT));
				e2->user.type = USER_KEY_CHAR;
				e2->keyboard.keycode = e->keyboard.keycode;
				_AL_KEYBOARD_STATE_SET_KEY_DOWN(icade_keyboard_state, e->keyboard.keycode);

				if (e->keyboard.keycode == config.getKey1()) {
					joy_b1_down();
				}
				else if (e->keyboard.keycode == config.getKey2()) {
					joy_b2_down();
				}
				else if (e->keyboard.keycode == config.getKey3()) {
					joy_b3_down();
				}
				else if (e->keyboard.keycode == config.getKeyLeft()) {
					joy_l_down();
				}
				else if (e->keyboard.keycode == config.getKeyRight()) {
					joy_r_down();
				}
				else if (e->keyboard.keycode == config.getKeyUp()) {
					joy_u_down();
				}
				else if (e->keyboard.keycode == config.getKeyDown()) {
					joy_d_down();
				}
				else {
					emit = true;
				}
			}
			else {
				_AL_KEYBOARD_STATE_CLEAR_KEY_DOWN(icade_keyboard_state, e->keyboard.keycode);

				if (e->keyboard.keycode == config.getKey1()) {
					if (area && !battle && !in_pause && config.getAlwaysCenter() == PAN_HYBRID) {
						area_panned_x = floor(area_panned_x);
						area_panned_y = floor(area_panned_y);
						area->center_view = true;
						center_button_pressed = true;
					}
					joy_b1_up();
				}
				else if (e->keyboard.keycode == config.getKey2()) {
					joy_b2_up();
				}
				else if (e->keyboard.keycode == config.getKey3()) {
					joy_b3_up();
				}
				else if (e->keyboard.keycode == config.getKeyLeft()) {
					joy_l_up();
				}
				else if (e->keyboard.keycode == config.getKeyRight()) {
					joy_r_up();
				}
				else if (e->keyboard.keycode == config.getKeyUp()) {
					joy_u_up();
				}
				else if (e->keyboard.keycode == config.getKeyDown()) {
					joy_d_up();
				}
				else {
					emit = true;
				}
			}
			if (emit) {
				al_emit_user_event(&user_event_source, e, destroy_event);
				if (e2) {
					al_emit_user_event(&user_event_source, e2, destroy_event);
				}
			}
		}
		if (!emit) {
			free(e);
			free(e2);
		}
	}
}
@end

static KBDelegate *text_delegate;

void initiOSKeyboard()
{
	text_delegate = [[KBDelegate alloc] init];
	[text_delegate performSelectorOnMainThread: @selector(start) withObject:nil waitUntilDone:YES];
	memset(&icade_keyboard_state, 0, sizeof icade_keyboard_state);
}

void switchiOSKeyboardIn()
{
	[text_delegate performSelectorOnMainThread: @selector(switch_in) withObject:nil waitUntilDone:YES];
}

static bool license_done;

static void all_done()
{
	UIViewController *root = [[[UIApplication sharedApplication] keyWindow] rootViewController];
	[root dismissViewControllerAnimated:YES completion:nil];
	license_done = true;
}

@interface MyTextView : UITextView
{
}
@end

@implementation MyTextView
@end

@interface LicenseViewController : UIViewController
{
	UIViewController *parent;
    NSAttributedString *txt;
    MyTextView *text_view;
}
- (id)initWithHTML:(NSAttributedString *)text;
- (void)done;
- (void)go:(UINavigationController *)nav;
- (void)createTextView:(NSObject *)unused;
- (void) viewDidAppear:(BOOL)animated;
@end

@implementation LicenseViewController
- (void) createTextView:(NSObject *)unused
{
    CGRect f;
    f.origin.x = 0;
    f.origin.y = 0;
    f.size.width = 0;
    f.size.height = 0;
    MyTextView *text_view = [[MyTextView alloc] initWithFrame:f];
    text_view.attributedText = txt;
    text_view.editable = FALSE;
    SEL selector = NSSelectorFromString(@"setSelectable:");
    if ([text_view respondsToSelector:selector]) {
        text_view.selectable = TRUE;
    }
    text_view.userInteractionEnabled = TRUE;

    self.view = text_view;
}
- (void) viewDidAppear:(BOOL)animated
{
    UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)];
    [self.navigationItem setRightBarButtonItem:bbi animated:NO];
}

- (id) initWithHTML:(NSAttributedString *)text
{
	self = [super initWithNibName:nil bundle:nil];
    
    txt = text;

	// Size doesn't seem to matter...
    [self performSelectorOnMainThread:@selector(createTextView:) withObject:nil waitUntilDone:YES];
	//text_view.attributedText = text;

    //UIBarButtonItem *bbi = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(done)];
    //self.navigationItem.backBarButtonItem = bbi;
    //[self.navigationItem setHidesBackButton:NO animated:NO];

    SEL selector2 = NSSelectorFromString(@"setEdgesForExtendedLayout:");
    if ([self respondsToSelector:selector2]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }

	return self;
}
- (void)done
{
	all_done();
}
- (void)go:(UINavigationController *)nav
{
    [[al_iphone_get_window(allegro_display) rootViewController] presentViewController:nav animated:YES completion:nil];
}
@end

bool ios_show_text(std::string fn_s)
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	NSString *text = @"Monster RPG 2 - 3rd Party Licenses\n\
\n\
Various open source libraries are used by the game including Allegro, FreeType, Lua, PhysicsFS and zlib. Licenses for some of those follow.\n\
\n\
--\n\
\n\
bstrlib (part of Allegro) is used under the following license:\n\
\n\
Copyright (c) 2002-2008 Paul Hsieh All rights reserved.\n\
\n\
Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:\n\
\n\
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.\n\
\n\
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.\n\
\n\
Neither the name of bstrlib nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.\n\
\n\
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS \"AS IS\" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.\n\
\n\
--\n\
\n\
Lua is used under the following license:\n\
\n\
Copyright (c) 1994-2015 Lua.org, PUC-Rio.\n\
\n\
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the \"Software\"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:\n\
\n\
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.\n\
\n\
THE SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.\n\
\n\
--\n\
\n\
Portions of this software are copyright © 2018 The FreeType Project (www.freetype.org). All rights reserved.\n\
\n\
--\n\
\n\
The DejaVu Sans font used by the game is used under the following licenses.\n\
\n\
Bitstream Vera Fonts Copyright:\n\
\n\
Copyright (c) 2003 by Bitstream, Inc. All Rights Reserved. Bitstream Vera is a trademark of Bitstream, Inc.\n\
\n\
Permission is hereby granted, free of charge, to any person obtaining a copy of the fonts accompanying this license (\"Fonts\") and associated documentation files (the \"Font Software\"), to reproduce and distribute the Font Software, including without limitation the rights to use, copy, merge, publish, distribute, and/or sell copies of the Font Software, and to permit persons to whom the Font Software is furnished to do so, subject to the following conditions:\n\
\n\
The above copyright and trademark notices and this permission notice shall be included in all copies of one or more of the Font Software typefaces.\n\
\n\
The Font Software may be modified, altered, or added to, and in particular the designs of glyphs or characters in the Fonts may be modified and additional glyphs or characters may be added to the Fonts, only if the fonts are renamed to names not containing either the words \"Bitstream\" or the word \"Vera\".\n\
\n\
This License becomes null and void to the extent applicable to Fonts or Font Software that has been modified and is distributed under the \"Bitstream Vera\" names.\n\
\n\
The Font Software may be sold as part of a larger software package but no copy of one or more of the Font Software typefaces may be sold by itself. THE FONT SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL BITSTREAM OR THE GNOME FOUNDATION BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.\n\
\n\
Arev Fonts Copyright:\n\
\n\
Copyright (c) 2006 by Tavmjong Bah. All Rights Reserved.\n\
\n\
Permission is hereby granted, free of charge, to any person obtaining a copy of the fonts accompanying this license (\"Fonts\") and associated documentation files (the \"Font Software\"), to reproduce and distribute the modifications to the Bitstream Vera Font Software, including without limitation the rights to use, copy, merge, publish, distribute, and/or sell copies of the Font Software, and to permit persons to whom the Font Software is furnished to do so, subject to the following conditions:\n\
\n\
The above copyright and trademark notices and this permission notice shall be included in all copies of one or more of the Font Software typefaces.\n\
\n\
The Font Software may be modified, altered, or added to, and in particular the designs of glyphs or characters in the Fonts may be modified and additional glyphs or characters may be added to the Fonts, only if the fonts are renamed to names not containing either the words \"Tavmjong Bah\" or the word \"Arev\".\n\
\n\
This License becomes null and void to the extent applicable to Fonts or Font Software that has been modified and is distributed under the \"Tavmjong Bah Arev\" names.\n\
\n\
The Font Software may be sold as part of a larger software package but no copy of one or more of the Font Software typefaces may be sold by itself.\n\
\n\
THE FONT SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL TAVMJONG BAH BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.\n\
\n\
--\n\
\n\
The Korean font (NanumGothicBold) is used under the following license:\n\
\n\
Copyright (c) 2010, NHN Corporation (http://www.nhncorp.com), with Reserved Font Name Nanum, Naver Nanum, NanumGothic, Naver NanumGothic, NanumMyeongjo, Naver NanumMyeongjo, NanumBrush, Naver NanumBrush, NanumPen, Naver NanumPen.\n\
\n\
This Font Software is licensed under the SIL Open Font License, Version 1.1. This license is copied below, and is also available with a FAQ at: http://scripts.sil.org/OFL\n\
\n\
SIL OPEN FONT LICENSE Version 1.1 - 26 February 2007\n\
\n\
PREAMBLE The goals of the Open Font License (OFL) are to stimulate worldwide development of collaborative font projects, to support the font creation efforts of academic and linguistic communities, and to provide a free and open framework in which fonts may be shared and improved in partnership with others.\n\
\n\
The OFL allows the licensed fonts to be used, studied, modified and redistributed freely as long as they are not sold by themselves. The fonts, including any derivative works, can be bundled, embedded, redistributed and/or sold with any software provided that any reserved names are not used by derivative works. The fonts and derivatives, however, cannot be released under any other type of license. The requirement for fonts to remain under this license does not apply to any document created using the fonts or their derivatives.\n\
\n\
DEFINITIONS \"Font Software\" refers to the set of files released by the Copyright Holder(s) under this license and clearly marked as such. This may include source files, build scripts and documentation.\n\
\n\
\"Reserved Font Name\" refers to any names specified as such after the copyright statement(s).\n\
\n\
\"Original Version\" refers to the collection of Font Software components as distributed by the Copyright Holder(s).\n\
\n\
\"Modified Version\" refers to any derivative made by adding to, deleting, or substituting -- in part or in whole -- any of the components of the Original Version, by changing formats or by porting the Font Software to a new environment.\n\
\n\
\"Author\" refers to any designer, engineer, programmer, technical writer or other person who contributed to the Font Software.\n\
\n\
PERMISSION & CONDITIONS Permission is hereby granted, free of charge, to any person obtaining a copy of the Font Software, to use, study, copy, merge, embed, modify, redistribute, and sell modified and unmodified copies of the Font Software, subject to the following conditions:\n\
\n\
1) Neither the Font Software nor any of its individual components, in Original or Modified Versions, may be sold by itself.\n\
\n\
2) Original or Modified Versions of the Font Software may be bundled, redistributed and/or sold with any software, provided that each copy contains the above copyright notice and this license. These can be included either as stand-alone text files, human-readable headers or in the appropriate machine-readable metadata fields within text or binary files as long as those fields can be easily viewed by the user.\n\
\n\
3) No Modified Version of the Font Software may use the Reserved Font Name(s) unless explicit written permission is granted by the corresponding Copyright Holder. This restriction only applies to the primary font name as presented to the users.\n\
\n\
4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font Software shall not be used to promote, endorse or advertise any Modified Version, except to acknowledge the contribution(s) of the Copyright Holder(s) and the Author(s) or with their explicit written permission.\n\
\n\
5) The Font Software, modified or unmodified, in part or in whole, must be distributed entirely under this license, and must not be distributed under any other license. The requirement for fonts to remain under this license does not apply to any document created using the Font Software.\n\
\n\
TERMINATION This license becomes null and void if any of the above conditions are not met.\n\
\n\
DISCLAIMER THE FONT SOFTWARE IS PROVIDED \"AS IS\", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.";
    
	// it's not HTML here, not supported on iOS 6
	NSAttributedString *html = [[NSAttributedString alloc] initWithString:text];
	if (html == nil) {
		[pool release];
		return false;
	}

	license_done = false;

    LicenseViewController *license_vc = [[LicenseViewController alloc] initWithHTML:html];

	UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:license_vc];
    
    [license_vc performSelectorOnMainThread:@selector(go:) withObject:nav waitUntilDone:YES];

	//UIViewController *root = [[[UIApplication sharedApplication] keyWindow] rootViewController];

	//[root presentViewController:nav animated:YES completion:nil];

	/*
	while (license_done == false) {
		SDL_PumpEvents();
		SDL_Delay(1);
	}

	SDL_SetHint(SDL_HINT_APPLE_TV_CONTROLLER_UI_EVENTS, "0");
	
	SDL_PumpEvents();
	SDL_FlushEvents(0, 0xffffffff);
	*/

	[pool release];

	return true;
}

bool ios_show_license()
{
    allegro_display = al_get_current_display();
	bool res = ios_show_text("3rd_party");
	return res;
}
