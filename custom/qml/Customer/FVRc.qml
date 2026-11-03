import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// RC signal in the customer top bar: four bars and the percentage the flight controller reports
// in RC_CHANNELS. Tap for details. ArduPilot reports nothing (0) until RSSI_TYPE is set, so the
// panel explains how to send the MK15's RSSI channel to the flight controller.
AbstractButton {
    id: control

    property var vehicle

    // Vehicle.rcRSSI: 0-100 %, 255 = unknown. 0 also means "not reported" (ArduPilot RSSI_TYPE 0).
    readonly property int   rssi:       vehicle ? vehicle.rcRSSI.rawValue : 0
    readonly property bool  valid:      rssi > 0 && rssi <= 100
    readonly property color _color:     !valid ? FVTheme.textDim : (rssi < 25 ? FVTheme.danger : (rssi < 50 ? FVTheme.warn : FVTheme.text))

    visible:        vehicle !== null && vehicle !== undefined
    implicitHeight: FVTheme.unit * 1.7
    implicitWidth:  rcRow.implicitWidth
    focusPolicy:    Qt.NoFocus
    onClicked:      mainWindow.showIndicatorDrawer(rcPage, control)

    contentItem: Item {
        Row {
            id:                 rcRow
            anchors.centerIn:   parent
            spacing:            FVTheme.unit * 0.25

            // Four bars
            Row {
                anchors.bottom: rcLabel.baseline
                spacing:        FVTheme.unit * 0.1

                Repeater {
                    model: 4

                    Rectangle {
                        required property int index

                        anchors.bottom: parent.bottom
                        width:          FVTheme.unit * 0.22
                        height:         FVTheme.unit * (0.35 + index * 0.22)
                        radius:         width / 3
                        color:          control.valid && control.rssi > index * 25 ? control._color : FVTheme.plateLine
                    }
                }
            }

            QGCLabel {
                id:         rcLabel
                text:       control.valid ? qsTr("RC %1%").arg(control.rssi) : qsTr("RC")
                color:      control.valid ? control._color : FVTheme.textDim
                font.bold:  true
            }
        }
    }

    Component {
        id: rcPage

        ToolIndicatorPage {
            contentComponent: SettingsGroupLayout {
                heading: qsTr("RC signal")

                GridLayout {
                    columns:        2
                    columnSpacing:  ScreenTools.defaultFontPixelWidth * 3
                    rowSpacing:     ScreenTools.defaultFontPixelHeight * 0.25

                    QGCLabel { text: qsTr("Signal strength") }
                    QGCLabel {
                        text:       control.valid ? qsTr("%1%").arg(control.rssi) : qsTr("Not reported by the drone")
                        font.bold:  control.valid
                    }
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 46
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    visible:                !control.valid
                    text:                   qsTr("The flight controller is not sending the remote's signal strength. To show it with a SIYI MK15: in the SIYI app, map the RSSI channel to a free channel (for example CH16); then, in Debug Mode, set the ArduPilot parameters RSSI_TYPE = 2, RSSI_CHANNEL = 16, RSSI_CHAN_LOW = 1000, RSSI_CHAN_HIGH = 2000 and reboot the drone.")
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 46
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    visible:                control.valid
                    text:                   qsTr("Signal strength of the remote control link as reported by the drone. Below 50% the bars turn amber, below 25% red: stay closer or bring the drone back.")
                }
            }
        }
    }
}
