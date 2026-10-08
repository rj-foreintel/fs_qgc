# ============================================================================
# ForeView custom build
#
# Branding only: app name/IDs come from cmake/CustomOverrides.cmake, logos
# are swapped in through ForeViewPlugin's resource interceptor, and Android
# launcher icons are overlaid on the stock android/ package template.
# ============================================================================

message(STATUS "ForeView: adding custom build layer")

# ----------------------------------------------------------------------------
# Android package template: stock android/ + our res/ overlay
# ----------------------------------------------------------------------------
if(ANDROID)
    set(_default_android_dir "${CMAKE_SOURCE_DIR}/android")
    set(_custom_android_dir  "${CMAKE_CURRENT_SOURCE_DIR}/android")
    set(_final_android_dir   "${CMAKE_BINARY_DIR}/custom/android")

    # copy_directory always overwrites. file(COPY) would skip our icons whenever
    # they share a timestamp with the stock ones, which is the norm after a git checkout.
    file(REMOVE_RECURSE "${_final_android_dir}")
    execute_process(COMMAND ${CMAKE_COMMAND} -E copy_directory "${_default_android_dir}" "${_final_android_dir}" COMMAND_ERROR_IS_FATAL ANY)
    execute_process(COMMAND ${CMAKE_COMMAND} -E copy_directory "${_custom_android_dir}" "${_final_android_dir}" COMMAND_ERROR_IS_FATAL ANY)

    # The stock build.gradle never sets applicationId, so Gradle would fall back
    # to the "org.mavlink.qgroundcontrol" namespace and ForeView would collide
    # with stock QGC on the device. Pin it to our package name.
    set(_gradle_file "${_final_android_dir}/build.gradle")
    file(READ "${_gradle_file}" _gradle)
    string(FIND "${_gradle}" "    defaultConfig {" _pos)
    if(_pos EQUAL -1)
        message(FATAL_ERROR "ForeView: could not find defaultConfig in ${_gradle_file}; update custom/CMakeLists.txt")
    endif()
    string(REPLACE "    defaultConfig {"
                   "    defaultConfig {\n        applicationId = \"${QGC_ANDROID_PACKAGE_NAME}\""
                   _gradle "${_gradle}")
    file(WRITE "${_gradle_file}" "${_gradle}")

    set_property(DIRECTORY APPEND PROPERTY CMAKE_CONFIGURE_DEPENDS
        "${_default_android_dir}/build.gradle"
        "${_default_android_dir}/AndroidManifest.xml"
    )

    set(QGC_ANDROID_PACKAGE_SOURCE_DIR "${_final_android_dir}" CACHE PATH "Path to a custom Android package template" FORCE)
    message(STATUS "ForeView: Android package template at ${QGC_ANDROID_PACKAGE_SOURCE_DIR} (applicationId ${QGC_ANDROID_PACKAGE_NAME})")
endif()

# ----------------------------------------------------------------------------
# Resources (logos looked up under :/Custom/... by the interceptor)
# ----------------------------------------------------------------------------
set(QGC_RESOURCES ${QGC_RESOURCES} ${CMAKE_CURRENT_SOURCE_DIR}/custom.qrc CACHE STRING "Paths to .qrc Resources" FORCE)

# ----------------------------------------------------------------------------
# Core plugin
# ----------------------------------------------------------------------------
set(CUSTOM_SOURCES
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ForeViewPlugin.cc
    ${CMAKE_CURRENT_SOURCE_DIR}/src/ForeViewPlugin.h
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_INCLUDE_DIRECTORIES
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_DEFINITIONS
    QGC_CUSTOM_BUILD
    CUSTOMHEADER="ForeViewPlugin.h"
    CUSTOMCLASS=ForeViewPlugin
    CACHE INTERNAL "" FORCE
)

set(CUSTOM_QT_COMPONENTS
    Core
    Qml
    CACHE INTERNAL "" FORCE
)
