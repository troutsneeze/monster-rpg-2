#include "monster2.hpp"

#ifdef ALLEGRO_WINDOWS
#define mkdir(a, b) _mkdir(a)
#include <allegro5/allegro_windows.h>
#endif

#include <sys/stat.h>

#ifdef ALLEGRO_ANDROID
#include "java.h"
#endif

#ifdef ALLEGRO_MACOSX
#include "macos.h"
#endif

#ifdef ALLEGRO_IPHONE
#include "iphone.h"
#endif

int myArgc;
char **myArgv;
double last_shake_check;


#if defined ALLEGRO_IPHONE
/*
 * Return the path to user resources (save states, configuration)
 */
static char *userResourcePath()
{
	static char path[MAX_PATH];

	ALLEGRO_PATH *user_path = al_get_standard_path(ALLEGRO_USER_DOCUMENTS_PATH);
	sprintf(path, "%s/", al_path_cstr(user_path, '/'));
	al_destroy_path(user_path);
	return path;
}
#endif

// NOTE: a5 changed path from home/Library/Preferences to Documents before 5.0.0
const char *getUserResource(const char *fmt, ...)
{
	va_list ap;

#ifdef ALLEGRO_IPHONE
	char file[MAX_PATH];
	static char result[MAX_PATH];
	char old[MAX_PATH];

	// This stuff is for backwards compatibility when
	// saves and screenshots etc were stored in Library/Preferences
	sprintf(file, "%s/MoRPG2", userResourcePath());
	if (!al_filename_exists(file))
		mkdir(file, 0755);

	va_start(ap, fmt);
	vsnprintf(file, MAX_PATH, fmt, ap);
	va_end(ap);

	sprintf(old, "%s/Library/Preferences/%s", getenv("HOME"), file);
	sprintf(result, "%s/MoRPG2/%s", userResourcePath(), file);

	if (al_filename_exists(old)) {
		rename(old, result);
	}
#elif defined ALLEGRO_ANDROID
	static char result[MAX_PATH];
	char s1[MAX_PATH];
	char s2[MAX_PATH];
	ALLEGRO_PATH *user_path = al_get_standard_path(ALLEGRO_USER_SETTINGS_PATH);
	strcpy(s1, al_path_cstr(user_path, ALLEGRO_NATIVE_PATH_SEP));
	al_drop_path_tail(user_path);
	strcpy(s2, al_path_cstr(user_path, ALLEGRO_NATIVE_PATH_SEP));
	al_destroy_path(user_path);

	if (!al_filename_exists(s2))
		mkdir(s2, 0755);
	if (!al_filename_exists(s1))
		mkdir(s1, 0755);

	// Changed to use SD card for config/saves so this checks if there is already a config NOT on the sd card and uses that if so
	// this maintains compatibility/save games of people who played before this change
	// to use the sd card, you need to uninstall/reinstall

	sprintf(result, "%s/config", s1);

	FILE *f = fopen(result, "r");
	bool exists = f != NULL;

	va_start(ap, fmt);
	vsnprintf(s2, MAX_PATH, fmt, ap);
	va_end(ap);

	if (exists) {
		fclose(f);
		sprintf(result, "%s/%s", s1, s2);
	}
	else {
		sprintf(result, "%s/%s", get_sdcarddir(), s2);
	}
#else
	static char result[MAX_PATH];
	char s1[MAX_PATH];
	char s2[MAX_PATH];
	ALLEGRO_PATH *user_path = al_get_standard_path(ALLEGRO_USER_SETTINGS_PATH);
	strcpy(s1, al_path_cstr(user_path, ALLEGRO_NATIVE_PATH_SEP));
	al_drop_path_tail(user_path);
	strcpy(s2, al_path_cstr(user_path, ALLEGRO_NATIVE_PATH_SEP));
	al_destroy_path(user_path);

	if (!al_filename_exists(s2))
		mkdir(s2, 0755);
	if (!al_filename_exists(s1))
		mkdir(s1, 0755);

	va_start(ap, fmt);
	vsnprintf(s2, MAX_PATH, fmt, ap);
	va_end(ap);

	sprintf(result, "%s/%s", s1, s2);
#endif
	
	return result;
}

#if 0
/*
 * Get the path to the game resources. First checks for a
 * MONSTER_DATA environment variable that points to the resources,
 * then a system-wide resource directory then the directory
 * "data" from the current directory.
 */
#ifndef ALLEGRO_ANDROID
static char* resourcePath()
{
	char tmp[MAX_PATH];
	static char result[MAX_PATH];

	ALLEGRO_PATH *resource_path = al_get_standard_path(ALLEGRO_RESOURCES_PATH);
	strcpy(tmp, al_path_cstr(resource_path, ALLEGRO_NATIVE_PATH_SEP));
	al_destroy_path(resource_path);
	sprintf(result, "%s/data/", tmp);

	return result;
}
#endif
#endif

const char *getResource(const char *fmt, ...)
{
	va_list ap;
	static char name[MAX_PATH];

#if !defined ALLEGRO_ANDROID
	strcpy(name, "data/");
#else
	strcpy(name, "assets/data/");
#endif
	va_start(ap, fmt);
	vsnprintf(name+strlen(name), (sizeof(name)/sizeof(*name))-1, fmt, ap);
	va_end(ap);

	return name;
}

bool pointInBox(int px, int py, int x1, int y1, int x2, int y2)
{
	if (px >= x1 && px < x2 && py >= y1 && py < y2)
		return true;
	return false;
}


const char *my_itoa(int i)
{
	static char buf[20];
	sprintf(buf, "%d", i);
	return buf;
}

int countOccurances(const char *s, char c)
{
	ALLEGRO_USTR *ustr = al_ustr_new(s);

	int count = 0;
	int32_t ch;
	int pos = 0;

	for (int i = 0; (ch = al_ustr_get_next(ustr, &pos)) != -1; i++) {
		if (ch == c)
			count++;
	}

	al_ustr_free(ustr);

	return count;
}

const char *findOccurance(const char *p, char c, int num)
{
	ALLEGRO_USTR *ustr = al_ustr_new(p);
	int32_t ch;
	int pos = 0;

	for (int i = 0; (ch = al_ustr_get_next(ustr, &pos)) != -1; i++) {
		if (ch == c) {
			num--;
			if (num == 0) {
				int o = al_ustr_offset(ustr, i);
				al_ustr_free(ustr);
				return p+o;
			}
		}
	}

	al_ustr_free(ustr);

	return NULL;
}


int check_arg(int argc, char **argv, const char *s)
{
	for (int i = 1; i < argc && argv[i]; i++) {
		if (!strcmp(argv[i], s))
			return i;
	}
	return -1;
}


// returns true to continue
void native_error(const char *msg, const char *msg2)
{
#if defined ALLEGRO_IPHONE || defined ALLEGRO_ANDROID || defined ALLEGRO_RASPBERRYPI
	fprintf(stderr, "%s\n", msg);
	exit(1);
#elif defined EDITOR
	return;
#else

	const char *ss = msg2 ? strstr(msg2, "data/") : NULL;
	if (ss) {
		ss += 5;
	}

	prepareForScreenGrab1();
	m_clear(black);
	prepareForScreenGrab2();

	if (inited) {
		if (prompt(msg, "Continue anyway?", 1, 0, ss ? ss : "", NULL, true)) {
			set_target_backbuffer();
			m_clear(al_map_rgb_f(0, 0, 0));
			drawBufferToScreen();
			m_flip_display();
			return;
		}
		else {
			unset_dragsize();
			exit(1);
		}
	}

#if !defined(__linux__)
	char buf[1000];
	const char *crap = "Error";
	snprintf(buf, 1000, "%s Continue anyway?", msg);
#ifdef ALLEGRO_MACOSX
	int button = al_show_native_message_box(display, ss ? ss : crap, ":(", buf, NULL, ALLEGRO_MESSAGEBOX_YES_NO);
#else
	int button = al_show_native_message_box(display, crap, ss ? ss : ":(", buf, NULL, ALLEGRO_MESSAGEBOX_YES_NO);
#endif

	if (button == 1) return;
	else {
		unset_dragsize();
		exit(1);
	}
#else
	fprintf(stderr, "%s\n", msg);
	unset_dragsize();
	exit(1);
#endif
#endif
}


bool isVowel(char c)
{
	const char *vowels = "aeiouAEIOU";
	char const *ptr = vowels;
	bool ret = false;

	while (*ptr) {
		if (c == *ptr) {
			ret = true;
			break;
		}
		ptr++;
	}

	return ret;
}

double iphone_line_times[4] = { -9999, -9999, -9999, -9999 };
double iphone_shake_time = -9999;
static bool need_release = false;

bool iphone_line(IPHONE_LINE_DIR dir, double since)
{
	if (need_release) {
		if (released) {
			need_release = false;
		}
		else {
			iphone_clear_line(dir);
			return false;
		}
	}
	if (al_current_time()-iphone_line_times[dir] < since) {
		need_release = true;
		return true;
	}
	return false;
}

bool iphone_shaken(double since)
{
#if defined ALLEGRO_IPHONE
	if (use_dpad) {
		return false;
	}
#endif
#if defined ALLEGRO_ANDROID
	if (!on_title_screen && use_dpad) return false;
#endif

	last_shake_check = al_get_time();

	if (al_current_time()-iphone_shake_time < since) {
		return true;
	}
	return false;
}

void iphone_clear_line(IPHONE_LINE_DIR dir)
{
	iphone_line_times[dir] = -9999;
}

void iphone_clear_shaken(void)
{
	iphone_shake_time = -9999;
}

void open_with_system(std::string filename)
{
#ifdef _WIN32
	ScreenDescriptor *sd = config.getWantedGraphicsMode();
	if (sd->fullscreen) {
		toggle_fullscreen();
	}
	ShellExecute(0, 0, filename.c_str(), 0, 0 , SW_SHOW);
#elif defined __linux__
	pid_t pid = fork();
	if (pid == 0) {
		system((std::string("xdg-open ") + filename).c_str());
		exit(0);
	}
#elif defined ALLEGRO_MACOSX
	macosx_open_with_system(filename);
#endif
}

#ifdef ANDROID
#include <jni.h>

extern "C" {
JNIEnv *_al_android_get_jnienv();
jobject _al_android_activity_object();
}
#endif

void show_license()
{
#if defined ALLEGRO_ANDROID
	JNIEnv* env = (JNIEnv *)_al_android_get_jnienv();
	jobject activity = (jobject)_al_android_activity_object();
	jclass clazz(env->GetObjectClass(activity));

	jmethodID method_id = env->GetMethodID(clazz, "showLicense", "()V");

	env->CallVoidMethod(activity, method_id);

	env->DeleteLocalRef(clazz);
#elif defined ALLEGRO_IPHONE
	ios_show_license();
#else
#ifdef ALLEGRO_MACOSX
	ALLEGRO_PATH *exename = al_get_standard_path(ALLEGRO_EXENAME_PATH);
	al_replace_path_component(exename, -1, "Resources");
	al_set_path_filename(exename, "3rd_party.html");
	std::string filename = al_path_cstr(exename, '/');
	al_destroy_path(exename);
#elif defined __linux__
	std::string argv0 = myArgv[0];
	size_t slash = argv0.rfind("/");
	std::string filename = argv0.substr(0, slash) + "/" + "3rd_party.html";
	filename = std::string("\"") + filename + std::string("\"");
#else
	std::string filename = "3rd_party.html";
#endif
	open_with_system(filename);
#endif
}
