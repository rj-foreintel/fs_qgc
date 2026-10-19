import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

import ForeView

// Camera settings panel next to the camera rail. Replaces the trips to the SIYI FPV app:
// main view (colour or thermal), thermal colours and thermal range, sent straight to the camera.
Rectangle {
    id: root

    signal closeRequested()

    width:          FVTheme.unit * 17
    height:         sheetColumn.implicitHeight + FVTheme.unit * 1.6
    radius:         FVTheme.radius
    color:          FVTheme.plate
    border.width:   1
    border.color:   FVTheme.plateLine

    // SIYI palette values (see ForeViewCamera::setThermalPalette)
    readonly property var _palettes: [
        { name: qsTr("White hot"),  value: 0 },
        { name: qsTr("Black hot"),  value: 10 },
        { name: qsTr("Ironbow"),    value: 3 },
        { name: qsTr("Rainbow"),    value: 4 },
        { name: qsTr("Red hot"),    value: 7 },
        { name: qsTr("Night"),      value: 5 }
    ]

    // Swallow taps so they do not reach the video or map underneath.
    MouseArea {
        anchors.fill: parent
    }

    ColumnLayout {
        id:                 sheetColumn
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        anchors.margins:    FVTheme.unit * 0.8
        spacing:            FVTheme.unit * 0.7

        RowLayout {
            Layout.fillWidth:   true
            spacing:            FVTheme.unit * 0.4

            QGCLabel {
                Layout.fillWidth:   true
                text:               qsTr("Camera settings")
                color:              FVTheme.text
                font.bold:          true
                font.pointSize:     FVTheme.largeFont
            }

            QGCLabel {
                text:   ForeViewCamera.connected ? ForeViewCamera.model : ""
                color:  FVTheme.textDim
            }

            FVRoundButton {
                iconName:   "close"
                size:       FVTheme.unit * 1.7
                onClicked:  root.closeRequested()
            }
        }

        QGCLabel {
            Layout.fillWidth:   true
            visible:            !ForeViewCamera.connected
            wrapMode:           Text.WordWrap
            color:              FVTheme.warn
            text:               qsTr("No answer from a SIYI camera. Check that it is powered and that the camera address in Settings > Video is correct.")
        }

        QGCLabel {
            Layout.fillWidth:   true
            visible:            ForeViewCamera.connected && !ForeViewCamera.thermalSupported
            wrapMode:           Text.WordWrap
            color:              FVTheme.textDim
            text:               qsTr("This camera has no thermal sensor.")
        }

        ColumnLayout {
            Layout.fillWidth:   true
            spacing:            FVTheme.unit * 0.7
            visible:            ForeViewCamera.thermalSupported

            QGCLabel {
                text:           qsTr("VIEW")
                color:          FVTheme.textDim
                font.bold:      true
                font.pointSize: FVTheme.smallFont
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            FVTheme.unit * 0.3

                FVChoiceButton {
                    Layout.fillWidth:   true
                    text:               qsTr("Colour")
                    selected:           !ForeViewCamera.sideBySide && !ForeViewCamera.thermalView
                    onClicked:          ForeViewCamera.setThermalView(false)
                }

                FVChoiceButton {
                    Layout.fillWidth:   true
                    text:               qsTr("Thermal")
                    selected:           !ForeViewCamera.sideBySide && ForeViewCamera.thermalView
                    onClicked:          ForeViewCamera.setThermalView(true)
                }

                // Colour left, thermal right: plays both of the camera's video streams.
                FVChoiceButton {
                    Layout.fillWidth:   true
                    text:               qsTr("Side by side")
                    selected:           ForeViewCamera.sideBySide
                    onClicked:          ForeViewCamera.setSideBySide(true)
                }
            }

            QGCLabel {
                text:           qsTr("THERMAL COLOURS")
                color:          FVTheme.textDim
                font.bold:      true
                font.pointSize: FVTheme.smallFont
            }

            GridLayout {
                Layout.fillWidth:   true
                columns:            3
                columnSpacing:      FVTheme.unit * 0.3
                rowSpacing:         FVTheme.unit * 0.3

                Repeater {
                    model: root._palettes

                    FVChoiceButton {
                        required property var modelData

                        Layout.fillWidth:   true
                        text:               modelData.name
                        selected:           ForeViewCamera.thermalPalette === modelData.value
                        onClicked: {
                            ForeViewCamera.setThermalPalette(modelData.value)
                            if (!ForeViewCamera.thermalView && !ForeViewCamera.sideBySide) {
                                ForeViewCamera.setThermalView(true)
                            }
                        }
                    }
                }
            }

            QGCLabel {
                text:           qsTr("THERMAL RANGE")
                color:          FVTheme.textDim
                font.bold:      true
                font.pointSize: FVTheme.smallFont
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            FVTheme.unit * 0.3

                FVChoiceButton {
                    Layout.fillWidth:   true
                    text:               qsTr("Everyday")
                    detail:             qsTr("-20 to 150 °C")
                    selected:           !ForeViewCamera.thermalHighRange
                    onClicked:          ForeViewCamera.setThermalHighRange(false)
                }

                FVChoiceButton {
                    Layout.fillWidth:   true
                    text:               qsTr("Hot objects")
                    detail:             qsTr("50 to 550 °C")
                    selected:           ForeViewCamera.thermalHighRange
                    onClicked:          ForeViewCamera.setThermalHighRange(true)
                }
            }
        }

        QGCLabel {
            Layout.fillWidth:   true
            visible:            ForeViewCamera.sdCardMissing
            wrapMode:           Text.WordWrap
            color:              FVTheme.warn
            text:               qsTr("No SD card in the camera: photos and videos cannot be saved.")
        }
    }
}
