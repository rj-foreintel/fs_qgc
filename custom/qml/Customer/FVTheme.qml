pragma Singleton

import QtQuick

import QGroundControl

// Colours and sizes of ForeView's customer Fly view.
//
// The Fly view draws on top of live video, so it does not follow QGC's light/dark palette:
// it always uses dark translucent plates with white text and saturated status colours,
// which stay readable over bright video and in sunlight.
QtObject {
    // ForeView palette: Horizon blue leads, Canopy green marks mission ("go") actions.
    readonly property color brand:      "#0e5a8a"
    readonly property color accent:     "#38c6f4"
    readonly property color accentInk:  "#04202c"
    readonly property color go:         "#1f7a55"

    // Status colours are the same in every palette so a warning always looks like a warning.
    readonly property color ok:         "#178a4c"
    readonly property color good:       "#22c55e"     // bright green for small marks (battery fill, ticks)
    readonly property color warn:       "#f5b301"
    readonly property color warnInk:    "#1a1406"
    readonly property color danger:     "#d92d3a"
    readonly property color idle:       "#5b6b78"
    readonly property color record:     "#ef4444"

    readonly property color plate:      "#bd061220"     // rgba(6, 18, 32, 0.74)
    readonly property color plateLine:  "#40ffffff"
    readonly property color chip:       "#24ffffff"
    readonly property color text:       "#ffffff"
    readonly property color textDim:    "#c9d3cf"

    readonly property real unit:        ScreenTools.defaultFontPixelHeight
    readonly property real margin:      unit * 0.6
    readonly property real radius:      unit * 0.8
    readonly property real smallFont:   ScreenTools.smallFontPointSize
    readonly property real normalFont:  ScreenTools.defaultFontPointSize
    readonly property real largeFont:   ScreenTools.largeFontPointSize
}
