import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// RC signal in the customer top bar: four bars and the percentage the flight controller reports
// in RC_CHANNELS. Tap for details. ArduPilot reports nothing until RSSI_TYPE is set, so the panel
// explains how to send the MK15's RSSI channel to the flight controller and, once it is set,
// shows that channel's live value against RSSI_CHAN_LOW / RSSI_CHAN_HIGH for calibration.
AbstractButton {
    id: control

    property var vehicle

    // Vehicle.rcRSSI: 0-100 %, 255 = not reported. 0 % is a real reading (signal lost).
    readonly property int   rssi:       vehicle ? vehicle.rcRSSI.rawValue : 255
    readonly property bool  valid:      rssi >= 0 && rssi <= 100
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
                id:         rcLayout
                heading:    qsTr("RC signal")

                // ArduPilot RSSI parameters (read only here)
                FactPanelController { id: controller }

                property var  _type:        controller.parameterExists(-1, "RSSI_TYPE") ? controller.getParameterFact(-1, "RSSI_TYPE", false) : null
                property bool _channelType: _type !== null && _type.rawValue === 2
                property var  _channel:     _channelType && controller.parameterExists(-1, "RSSI_CHANNEL") ? controller.getParameterFact(-1, "RSSI_CHANNEL", false) : null
                property var  _low:         _channelType && controller.parameterExists(-1, "RSSI_CHAN_LOW") ? controller.getParameterFact(-1, "RSSI_CHAN_LOW", false) : null
                property var  _high:        _channelType && controller.parameterExists(-1, "RSSI_CHAN_HIGH") ? controller.getParameterFact(-1, "RSSI_CHAN_HIGH", false) : null
                property int  _channelPwm:  0
                property var  _radio:       control.vehicle ? control.vehicle.radioStatus : null

                // QGC stores RADIO_STATUS rssi as signed dBm; undo that to show the byte the radio sent.
                function _radioRaw(fact) {
                    const v = fact.rawValue
                    return v < 0 ? v + 256 : v
                }

                Connections {
                    target: control.vehicle
                    function onRcChannelsRawChanged(channelValues) {
                        const index = rcLayout._channel ? rcLayout._channel.rawValue - 1 : -1
                        rcLayout._channelPwm = (index >= 0 && index < channelValues.length) ? channelValues[index] : 0
                    }
                }

                GridLayout {
                    columns:        2
                    columnSpacing:  ScreenTools.defaultFontPixelWidth * 3
                    rowSpacing:     ScreenTools.defaultFontPixelHeight * 0.25

                    QGCLabel { text: qsTr("Signal strength") }
                    QGCLabel {
                        text:       control.valid ? qsTr("%1%").arg(control.rssi) : qsTr("Not reported by the drone")
                        font.bold:  control.valid
                    }

                    QGCLabel { text: qsTr("RSSI source"); visible: rcLayout._type !== null }
                    QGCLabel {
                        text:       rcLayout._type ? rcLayout._type.enumStringValue : ""
                        visible:    rcLayout._type !== null
                    }

                    QGCLabel {
                        text:       rcLayout._channel ? qsTr("Channel %1 now").arg(rcLayout._channel.rawValue) : ""
                        visible:    rcLayout._channel !== null
                    }
                    QGCLabel {
                        text:       rcLayout._channelPwm > 0 ? qsTr("%1 µs").arg(rcLayout._channelPwm) : qsTr("waiting…")
                        font.bold:  true
                        visible:    rcLayout._channel !== null
                    }

                    // RADIO_STATUS from the telemetry link, raw as the radio sends it (RSSI_TYPE 5
                    // reads this as 0-254; a radio that reports 0-100 then tops out at 39%).
                    QGCLabel {
                        text:       qsTr("Telemetry radio")
                        visible:    rcLayout._radio !== null && rcLayout._radio.telemetryAvailable
                    }
                    QGCLabel {
                        text:       rcLayout._radio ? qsTr("RSSI %1 (local) / %2 (remote)").arg(rcLayout._radioRaw(rcLayout._radio.lrssi)).arg(rcLayout._radioRaw(rcLayout._radio.rrssi)) : ""
                        visible:    rcLayout._radio !== null && rcLayout._radio.telemetryAvailable
                    }

                    QGCLabel {
                        text:       qsTr("0% / 100% at")
                        visible:    rcLayout._low !== null && rcLayout._high !== null
                    }
                    QGCLabel {
                        text:       rcLayout._low && rcLayout._high ? qsTr("%1 / %2 µs").arg(rcLayout._low.rawValue).arg(rcLayout._high.rawValue) : ""
                        visible:    rcLayout._low !== null && rcLayout._high !== null
                    }
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 46
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    visible:                !control.valid
                    text:                   qsTr("The flight controller is not sending the remote's signal strength. To show it with a SIYI MK15: in the SIYI app, map the RSSI channel to a free channel (for example CH16); then, in Debug Mode, set the ArduPilot parameters RSSI_TYPE = 2 and RSSI_CHANNEL = 16, and reboot the drone. Then set the 0% / 100% values as described here.")
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 46
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    visible:                rcLayout._channel !== null
                    text:                   qsTr("100% is RSSI_CHAN_HIGH. If the signal stays low even next to the drone, set RSSI_CHAN_HIGH (Debug Mode) to the channel value shown above with the remote next to the drone, and RSSI_CHAN_LOW to the value the channel shows when the signal is weakest.")
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 46
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    visible:                rcLayout._type !== null && rcLayout._type.rawValue === 5
                    text:                   qsTr("RSSI_TYPE 5 reads the telemetry radio's RSSI as 0-254. A radio that reports 0-100 can never show more than 39%. Use the remote's RSSI channel instead: in the SIYI app map RSSI to a free channel (for example CH16), then set RSSI_TYPE = 2 and RSSI_CHANNEL = 16 in Debug Mode.")
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 46
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    visible:                control.valid
                    text:                   qsTr("Below 50% the bars turn amber, below 25% red: stay closer or bring the drone back.")
                }
            }
        }
    }
}
