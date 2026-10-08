# ============================================================================
# ForeView branding overrides
#
# Loaded by the top-level CMakeLists.txt (before project()) whenever a
# `custom/` directory exists. Only branding is changed here: every flight
# stack (ArduPilot and PX4) and the stock QGC UI stay enabled.
# ============================================================================

set(_foreview_dir "${CMAKE_SOURCE_DIR}/custom")

# ----------------------------------------------------------------------------
# Application identity
# ----------------------------------------------------------------------------
set(QGC_APP_NAME        "ForeView"                     CACHE STRING "App Name" FORCE)
set(QGC_APP_DESCRIPTION "ForeView Ground Control Station" CACHE STRING "Application description" FORCE)
set(QGC_ORG_NAME        "Foreintel Solutions"          CACHE STRING "Organization name" FORCE)
string(TIMESTAMP _foreview_year "%Y")
set(QGC_APP_COPYRIGHT   "Copyright (c) ${_foreview_year} Foreintel Solutions Pvt. Ltd. Based on QGroundControl." CACHE STRING "Copyright notice" FORCE)

# Always build as a release: the window title, settings folder and Android
# label read "ForeView" instead of QGC's development-build "ForeView Daily".
set(QGC_STABLE_BUILD ON CACHE BOOL "Stable release build (disables daily build features)" FORCE)

# Reverse-domain identifier. It is the Android application ID, the Linux
# desktop-entry name and the macOS bundle ID. A different ID from stock QGC
# means ForeView installs next to QGroundControl instead of replacing it.
# Do not change it once ForeView is deployed: Android treats a new ID as a
# different app.
set(QGC_PACKAGE_NAME         "com.foreintel.foreview" CACHE STRING "Package identifier" FORCE)
set(QGC_ANDROID_PACKAGE_NAME "${QGC_PACKAGE_NAME}"    CACHE STRING "Android package identifier" FORCE)
set(QGC_MACOS_BUNDLE_ID      "${QGC_PACKAGE_NAME}"    CACHE STRING "macOS bundle identifier" FORCE)

# ----------------------------------------------------------------------------
# Icons
# ----------------------------------------------------------------------------
# Windows: executable icon, installer icon and installer header
set(QGC_WINDOWS_ICON_PATH           "${_foreview_dir}/deploy/windows/ForeView.ico"     CACHE FILEPATH "Windows Icon Path" FORCE)
set(QGC_WINDOWS_INSTALL_HEADER_PATH "${_foreview_dir}/deploy/windows/installheader.bmp" CACHE FILEPATH "Windows Install Header Path" FORCE)

# Linux: desktop/AppImage icons
set(QGC_APPIMAGE_ICON_256_PATH      "${_foreview_dir}/res/icons/ForeView_256.png" CACHE FILEPATH "AppImage 256x256 icon path" FORCE)
set(QGC_APPIMAGE_ICON_SCALABLE_PATH "${_foreview_dir}/res/icons/ForeView.svg"     CACHE FILEPATH "AppImage SVG icon path" FORCE)
set(QGC_APPIMAGE_METADATA_PATH      "${_foreview_dir}/deploy/linux/foreview.appdata.xml.in" CACHE FILEPATH "AppImage metadata path" FORCE)

# The stock AppRun looks for a binary named QGroundControl; teach it ForeView.
file(READ "${CMAKE_SOURCE_DIR}/deploy/linux/AppRun" _foreview_apprun)
string(REPLACE "for expected_name in QGroundControl"
               "for expected_name in ${QGC_APP_NAME} QGroundControl"
               _foreview_apprun "${_foreview_apprun}")
file(WRITE "${CMAKE_BINARY_DIR}/foreview/AppRun" "${_foreview_apprun}")
file(CHMOD "${CMAKE_BINARY_DIR}/foreview/AppRun"
     PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
set(QGC_APPIMAGE_APPRUN_PATH "${CMAKE_BINARY_DIR}/foreview/AppRun" CACHE FILEPATH "AppImage AppRun script path" FORCE)

# macOS
set(QGC_MACOS_ICON_PATH             "${_foreview_dir}/res/icons/ForeView.icns"    CACHE FILEPATH "MacOS Icon Path" FORCE)

# Android launcher icons are overlaid from custom/android/res (see custom/CMakeLists.txt).
