#ifndef MACOS_H
#define MACOS_H

#include <allegro5/allegro.h>

#ifdef ALLEGRO_MACOSX
void macosx_open_with_system(std::string filename);
#endif

#endif
