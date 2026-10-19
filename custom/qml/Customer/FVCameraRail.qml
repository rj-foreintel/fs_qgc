import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

import ForeView

// Camera controls on the right edge of the customer Fly view. Talks to the SIYI camera
// directly (ForeViewCamera): colour/thermal, zoom (press and hold), photo or video,
// centre the gimbal, and the camera settings panel.
Rectangle {
    id: root

    property bool videoMode:    false
    property bool sheetOpen:    false

    signal sheetToggleRequested()

    width:          FVTheme.unit * 4
    height:         railColumn.implicitHeight + FVTheme.unit * 1.2
    radius:         width / 2
    color:          FVTheme.plate

    readonly property bool _connected: ForeViewCamera.connected

    // Recording started elsewhere (e.g. the remote's button) still shows as video mode here.
    Connections {
        target: ForeViewCamera
        function onRecordingChanged() {
            if (ForeViewCamera.recording) {
                root.videoMode = true
            }
        }
    }

    Column {
        id:                         railColumn
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.verticalCenter:     parent.verticalCenter
        spacing:                    FVTheme.unit * 0.5

        Column {
            anchors.horizontalCenter:   parent.horizontalCenter
            spacing:                    FVTheme.unit * 0.2
            visible:                    ForeViewCamera.thermalSupported

            FVChoiceButton {
                width:      FVTheme.unit * 3
                text:       qsTr("RGB")
                selected:   !ForeViewCamera.sideBySide && !ForeViewCamera.thermalView
                onClicked:  ForeViewCamera.setThermalView(false)
            }

            FVChoiceButton {
                width:      FVTheme.unit * 3
                text:       qsTr("IR")
                selected:   !ForeViewCamera.sideBySide && ForeViewCamera.thermalView
                onClicked:  ForeViewCamera.setThermalView(true)
            }

            // RGB and IR side by side
            FVChoiceButton {
                width:      FVTheme.unit * 3
                text:       qsTr("Both")
                selected:   ForeViewCamera.sideBySide
                onClicked:  ForeViewCamera.setSideBySide(true)
            }
        }

        FVRoundButton {
            anchors.horizontalCenter:   parent.horizontalCenter
            iconName:                   "plus"
            enabled:                    root._connected
            onPressed:                  ForeViewCamera.zoomIn()
            onReleased:                 ForeViewCamera.zoomStop()
            onCanceled:                 ForeViewCamera.zoomStop()
        }

        QGCLabel {
            anchors.horizontalCenter:   parent.horizontalCenter
            text:                       qsTr("%1×").arg(ForeViewCamera.zoom.toFixed(1))
            color:                      FVTheme.text
            font.bold:                  true
            opacity:                    root._connected ? 1 : 0.45
        }

        FVRoundButton {
            anchors.horizontalCenter:   parent.horizontalCenter
            iconName:                   "minus"
            enabled:                    root._connected
            onPressed:                  ForeViewCamera.zoomOut()
            onReleased:                 ForeViewCamera.zoomStop()
            onCanceled:                 ForeViewCamera.zoomStop()
        }

        // Shutter: white disc for a photo, red disc (red square while recording) for video.
        AbstractButton {
            id:                         shutter
            anchors.horizontalCenter:   parent.horizontalCenter
            implicitWidth:              FVTheme.unit * 3.3
            implicitHeight:             implicitWidth
            enabled:                    root._connected
            opacity:                    enabled ? 1 : 0.45
            focusPolicy:                Qt.NoFocus

            onClicked: {
                if (root.videoMode) {
                    ForeViewCamera.toggleRecording()
                } else {
                    ForeViewCamera.takePhoto()
                }
            }

            background: Rectangle {
                radius:         width / 2
                color:          "transparent"
                border.width:   3
                border.color:   FVTheme.text
            }

            contentItem: Item {
                Rectangle {
                    readonly property bool _recording: root.videoMode && ForeViewCamera.recording

                    anchors.centerIn:   parent
                    width:              _recording ? shutter.width * 0.36 : shutter.width * 0.72
                    height:             width
                    radius:             _recording ? FVTheme.unit * 0.2 : width / 2
                    color:              root.videoMode ? FVTheme.record : FVTheme.text
                    opacity:            shutter.pressed ? 0.7 : 1

                    Behavior on width { NumberAnimation { duration: 120 } }
                }
            }
        }

        FVRoundButton {
            anchors.horizontalCenter:   parent.horizontalCenter
            iconName:                   root.videoMode ? "video" : "photo"
            enabled:                    !ForeViewCamera.recording
            onClicked:                  root.videoMode = !root.videoMode
        }

        FVRoundButton {
            anchors.horizontalCenter:   parent.horizontalCenter
            iconName:                   "center"
            enabled:                    root._connected
            onClicked:                  ForeViewCamera.center()
        }

        FVRoundButton {
            anchors.horizontalCenter:   parent.horizontalCenter
            iconName:                   "sliders"
            highlighted:                root.sheetOpen
            onClicked:                  root.sheetToggleRequested()
        }
    }
}
