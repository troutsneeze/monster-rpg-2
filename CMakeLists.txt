project(monster-rpg-2)
cmake_minimum_required(VERSION 2.6)

OPTION(KCM_AUDIO "Use Allegro audio instead of BASS" off)
OPTION(RASPBERRYPI "Compile for Raspberry Pi" off)
OPTION(STEAMWORKS "Enable Steamworks" off)

# function to copy files to build dir:
function(copy_file_to_build target file dest)
   add_custom_target(${target} ALL DEPENDS ${dest})

   add_custom_command(
      OUTPUT ${dest}
      COMMAND "${CMAKE_COMMAND}" -E copy
         "${CMAKE_CURRENT_SOURCE_DIR}/${file}" ${dest}
   )
endfunction(copy_file_to_build)

include_directories("${CMAKE_SOURCE_DIR}/include")

if(NOT ("${USER_INCLUDE_PATH}" STREQUAL ""))
	include_directories(${USER_INCLUDE_PATH})
endif()
if(NOT ("${USER_LIBRARY_PATH}" STREQUAL ""))
	link_directories(${USER_LIBRARY_PATH})
endif()

set(SOURCE_FILES
	src/3d.cpp
	src/Animation.cpp
	src/AnimationSet.cpp
	src/Area.cpp
	src/CombatActions.cpp
	src/CombatEnemy.cpp
	src/CombatEntity.cpp
	src/CombatPlayer.cpp
	src/Combatant.cpp
	src/Configuration.cpp
	src/Frame.cpp
	src/GenericEffect.cpp
	src/Image.cpp
	src/Input.cpp
	src/Items.cpp
	src/Object.cpp
	src/Player.cpp
	src/Spells.cpp
	src/Tile.cpp
	src/atlas.cpp
	src/atlas_accessor.cpp
	src/battle.cpp
	src/debug.cpp
	src/equipment.cpp
	src/graphics.cpp
	src/inventory.cpp
	src/init.cpp
	src/io.cpp
	src/lander.cpp
	src/my_load_bitmap.cpp
	src/pause.cpp
	src/redundant.cpp
	src/script.cpp
	src/shooter.cpp
	src/sound.cpp
	src/tgui.cpp
	src/translate.cpp
	src/util.cpp
	src/widgets.cpp
	src/xml.cpp
	src/monster2.cpp
)

if(WIN32)
	list(APPEND SOURCE_FILES monster-rpg-2.manifest icons/windows_icon.rc)
endif()

add_executable(MonsterRPG2 ${SOURCE_FILES})

if(KCM_AUDIO)
	if(NOT WIN32)
		LIST(APPEND EXTRA_LIBS "asound" "pulse-simple" "pulse" "vorbisfile" "vorbis" "ogg")
	endif()
endif()

if(MINGW)
	set(LFLAGS "${LFLAGS} -static -static-libgcc -static-libstdc++")
	set(LFLAGS "${LFLAGS} -Wl,--subsystem,windows")
	set(CFLAGS "${CFLAGS} -DALLEGRO_STATICLINK -DALLEGRO_UNSTABLE")

	if(KCM_AUDIO)
		set(CFLAGS "${CFLAGS} -DKCM_AUDIO")
	endif()

	if(STEAMWORKS)
		set(CFLAGS "${CFLAGS} -DSTEAMWORKS")
	endif()

	set_target_properties(MonsterRPG2 PROPERTIES COMPILE_FLAGS "${CFLAGS}")
	set_target_properties(MonsterRPG2 PROPERTIES LINK_FLAGS "${LFLAGS}")

	# Add for KCM_AUDIO
	#"vorbisfile"
	#"vorbis"
	#"ogg"
	list(APPEND EXTRA_LIBS
		"allegro_monolith-physfs-static"
		"dbghelp"
		"dxguid"
		"dinput8"
		"dsound"
		"d3d9"
		"d3dx9"
		"opengl32"
		"comdlg32"
		"gdi32"
		"gdiplus"
		"kernel32"
		"ole32"
		"psapi"
		"shlwapi"
		"user32"
		"uuid"
		"winmm"
		"lua5.2"
		"freetype"
		"physfs"
		"zlibstatic"
	)

	if(STEAMWORKS)
		list(APPEND EXTRA_LIBS "steam_api")
	endif()

	SET(MAIN_LIBS 
		${ICON_OBJ}
		${EXTRA_LIBS}
	)

	if(KCM_AUDIO)
		LIST(APPEND MAIN_LIBS "ws2_32" "dsound")
	else()
		LIST(APPEND MAIN_LIBS "/home/trent/code/win-lib/bass.lib")
	endif(KCM_AUDIO)
elseif(WIN32)
	set(CFLAGS "/MT /MP /D_USE_MATH_DEFINES /DALLEGRO_STATICLINK /EHsc /D_WIN32_WINNT=0x501 /DALLEGRO_UNSTABLE")

	if(KCM_AUDIO)
		set(CFLAGS "${CFLAGS} /DKCM_AUDIO")
	endif()

	if(STEAMWORKS)
		set(CFLAGS "${CFLAGS} /DSTEAMWORKS")
	endif()

	set_target_properties(MonsterRPG2 PROPERTIES COMPILE_FLAGS "${CFLAGS}")

	set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} /SAFESEH:NO /SUBSYSTEM:WINDOWS")

	list(APPEND EXTRA_LIBS
		"dbghelp"
		"dxguid"
		"dinput8"
		"dsound"
		"d3d9"
		"d3dx9"
		"opengl32"
		"comdlg32"
		"gdi32"
		"gdiplus"
		"kernel32"
		"ole32"
		"psapi"
		"shlwapi"
		"user32"
		"uuid"
		"winmm"
		"lua5.2"
		"freetype"
		"physfs"
		"zlibstatic"
		"allegro_monolith-static"
	)

	if(STEAMWORKS)
		list(APPEND EXTRA_LIBS "steam_api")
	endif()

	SET(MAIN_LIBS 
		${ICON_OBJ}
		${EXTRA_LIBS}
	)

	if(KCM_AUDIO)
		LIST(APPEND MAIN_LIBS "ws2_32" "dsound")
	else()
		LIST(APPEND MAIN_LIBS "bass")
	endif(KCM_AUDIO)
elseif(APPLE)
	set(CFLAGS "${CFLAGS} -DNO_GAMECENTER")
	set(SOURCE_FILES ${SOURCE_FILES} src/gamecenter.mm)
	set(CFLAGS "${CFLAGS} -DALLEGRO_UNSTABLE")
	if(KCM_AUDIO)
		set(CFLAGS "${CFLAGS} -DKCM_AUDIO")
	endif()

	set(ALLEGRO_MAIN_LIB "allegro_main${ALLEGRO_SUFFIX}")
	FIND_LIBRARY(OPENGL_LIBRARY OpenGL)
	FIND_LIBRARY(FOUNDATION_LIBRARY Foundation)
	FIND_LIBRARY(APPSERVICES_LIBRARY ApplicationServices)
	FIND_LIBRARY(APPKIT_LIBRARY AppKit)
	FIND_LIBRARY(IOKIT_LIBRARY IOKit)
	FIND_LIBRARY(AUDIOTOOLBOX_LIBRARY AudioToolbox)
	FIND_LIBRARY(SECURITY_LIBRARY Security)
	LIST(APPEND EXTRA_LIBS ${IOKIT_LIBRARY} ${OPENGL_LIBRARY} ${FOUNDATION_LIBRARY} ${APPSERVICES_LIBRARY} ${APPKIT_LIBRARY} ${AUDIOTOOLBOX_LIBRARY} ${GAMEKIT_LIBRARY} ${SECURITY_LIBRARY})
	SET(MAIN_LIBS 
		allegro_ttf${ALLEGRO_SUFFIX}
		allegro_font${ALLEGRO_SUFFIX}
		allegro_primitives${ALLEGRO_SUFFIX}
		allegro_dialog${ALLEGRO_SUFFIX}
		allegro_memfile${ALLEGRO_SUFFIX}
		allegro_image${ALLEGRO_SUFFIX}
		allegro_physfs${ALLEGRO_SUFFIX}
		allegro${ALLEGRO_SUFFIX} ${ALLEGRO_MAIN_LIB}
		${EXTRA_LIBS}
		/Users/trent/code/local/lib/libfreetype.a
		/Users/trent/code/local/lib/libphysfs.a
		/Users/trent/code/local/lib/libz.a
		/Users/trent/code/local/lib/liblua.a
	)
	if(KCM_AUDIO)
		set(LFLAGS "${LFLAGS} -framework OpenAL")
	else()
		LIST(APPEND MAIN_LIBS "bass")
	endif()
	set_target_properties(MonsterRPG2 PROPERTIES COMPILE_FLAGS "${CFLAGS}")
	set_target_properties(MonsterRPG2 PROPERTIES LINK_FLAGS "${LFLAGS}")
else()
	set(CFLAGS "${CFLAGS} -DALLEGRO_UNSTABLE")
	if(KCM_AUDIO)
		set(CFLAGS "${CFLAGS} -DKCM_AUDIO")
	endif()
	set(CFLAGS "${CFLAGS} -std=c++0x")
	set(LFLAGS "${LFLAGS} -Wl,-rpath,\$ORIGIN")
	SET(MAIN_LIBS 
		allegro
		allegro_primitives
		allegro_memfile
		allegro_font
		allegro_ttf
		allegro_physfs
		allegro_image
		${EXTRA_LIBS}
		Xcursor Xi Xinerama Xrandr SM ICE X11 Xext Xpm
	)
	if(NOT KCM_AUDIO)
		LIST(APPEND MAIN_LIBS "${CMAKE_BINARY_DIR}/libbass.so")
	endif()
	if(STEAMWORKS)
		LIST(APPEND MAIN_LIBS "${CMAKE_BINARY_DIR}/libsteam_api.so")
	endif()
	if(RASPBERRYPI)
		set(CFLAGS "${CFLAGS} -Os -march=armv6 -mfpu=vfp -mfloat-abi=hard")
		include_directories("/opt/vc/include")
		include_directories("/opt/vc/include/interface/vcos/pthreads")
		link_directories(
			"/opt/vc/lib"
		)
		LIST(APPEND MAIN_LIBS
			brcmGLESv2
			brcmEGL
			bcm_host
			m
			pthread
			/usr/lib/arm-linux-gnueabihf/libfreetype.a
			/usr/local/lib/libphysfs.a
			/usr/lib/arm-linux-gnueabihf/libpng.a
			/usr/lib/arm-linux-gnueabihf/libz.a
			/usr/lib/arm-linux-gnueabihf/liblua5.2.a
			dl
		)
	else()

		LIST(APPEND MAIN_LIBS
			GL
			GLU
			physfs
			freetype
			z
			png
			lua5.2
			pthread
			dl
		)
	endif()
	
	set_target_properties(MonsterRPG2 PROPERTIES COMPILE_FLAGS "${CFLAGS}")
	set_target_properties(MonsterRPG2 PROPERTIES LINK_FLAGS "${LFLAGS}")
endif()

target_link_libraries(
	MonsterRPG2
	${MAIN_LIBS}
) 
