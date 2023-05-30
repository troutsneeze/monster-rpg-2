#include <allegro5/allegro.h>

#include <string>

#include <Cocoa/Cocoa.h>

#ifdef ALLEGRO_MACOSX
void macosx_open_with_system(std::string filename)
{
	[[NSWorkspace sharedWorkspace] openFile:[NSString stringWithUTF8String:filename.c_str()]];
}
#endif

