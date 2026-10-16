import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

import ForeView

// Top status bar of the customer Fly view:
//   [ForeView menu] [status] [flight mode, read only] ... [GPS] [RC] [battery] [LIVE] [settings]
// Tapping the ForeView name opens the view menu; seven quick taps open the Debug Mode prompt.
Rectangle {
    id: root

    signal unlockRequested()

    height: FVTheme.unit * 2.7
    color:  FVTheme.plate

    property var    _vehicle:           QGroundControl.multiVehicleManager.activeVehicle
    property bool   _commLost:          _vehicle ? _vehicle.vehicleLinkManager.communicationLost : false
    property var    _battery:           _vehicle && _vehicle.batteries.count > 0 ? _vehicle.batteries.get(0) : null
    property real   _batteryPercent:    _battery ? _battery.percentRemaining.rawValue : NaN
    property real   _batterySeconds:    _battery ? _battery.timeRemaining.rawValue : NaN
    property int    _gpsCount:          _vehicle ? _vehicle.gps.count.rawValue : 0
    property int    _gpsLock:           _vehicle ? _vehicle.gps.lock.rawValue : 0
    property int    _rssi:              _vehicle ? _vehicle.rcRSSI.rawValue : 0
    property bool   _rssiValid:         _rssi > 0 && _rssi <= 100

    // Readiness, following QGC's main status indicator.
    readonly property bool _ready: {
        if (!_vehicle) {
            return false
        }
        if (_vehicle.healthAndArmingCheckReport.supported) {
            return _vehicle.healthAndArmingCheckReport.canArm
        }
        if (_vehicle.readyToFlyAvailable) {
            return _vehicle.readyToFly
        }
        return _vehicle.allSensorsHealthy && _vehicle.autopilotPlugin.setupComplete
    }

    readonly property string _statusText: {
        if (!_vehicle)              return qsTr("Not connected")
        if (_commLost)              return qsTr("Signal lost")
        if (_vehicle.flying)        return qsTr("Flying")
        if (_vehicle.landing)       return qsTr("Landing")
        if (_vehicle.armed)         return qsTr("Armed")
        return _ready ? qsTr("Ready to fly") : qsTr("Not ready")
    }

    readonly property color _statusColor: {
        if (!_vehicle)              return FVTheme.idle
        if (_commLost)              return FVTheme.danger
        if (_vehicle.armed)         return FVTheme.ok
        return _ready ? FVTheme.ok : FVTheme.warn
    }

    function _batteryColor() {
        if (isNaN(_batteryPercent)) return FVTheme.text
        if (_batteryPercent < 15)   return FVTheme.danger
        if (_batteryPercent < 30)   return FVTheme.warn
        return FVTheme.good
    }

    // ---- ForeView name: menu on one tap, Debug Mode prompt on seven quick taps ----
    property int _tapCount: 0

    Timer {
        id:         tapTimer
        interval:   400
        onTriggered: {
            if (root._tapCount < 7) {
                mainWindow.showToolSelectDialog()
            }
            root._tapCount = 0
        }
    }

    RowLayout {
        anchors.fill:           parent
        anchors.leftMargin:     FVTheme.margin
        anchors.rightMargin:    FVTheme.margin
        spacing:                FVTheme.unit * 0.7

        AbstractButton {
            id:                 brandButton
            Layout.fillHeight:  true
            implicitWidth:      brandRow.implicitWidth
            focusPolicy:        Qt.NoFocus

            onClicked: {
                root._tapCount++
                if (root._tapCount >= 7) {
                    tapTimer.stop()
                    root._tapCount = 0
                    root.unlockRequested()
                } else {
                    tapTimer.restart()
                }
            }

            contentItem: Row {
                id:         brandRow
                spacing:    FVTheme.unit * 0.4

                FVIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name:                   "menu"
                    height:                 FVTheme.unit * 1.1
                }

                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   QGroundControl.appName
                    color:                  FVTheme.text
                    font.bold:              true
                    font.pointSize:         FVTheme.largeFont
                }
            }
        }

        // Status pill; tap to read the drone's messages (e.g. why it is not ready).
        AbstractButton {
            id:                 statusButton
            Layout.alignment:   Qt.AlignVCenter
            implicitHeight:     FVTheme.unit * 1.7
            implicitWidth:      statusLabel.implicitWidth + FVTheme.unit * 1.4
            focusPolicy:        Qt.NoFocus
            enabled:            root._vehicle !== null
            onClicked:          mainWindow.showIndicatorDrawer(messagesPage, statusButton)

            background: Rectangle {
                radius: height / 2
                color:  root._statusColor
            }

            contentItem: QGCLabel {
                id:                     statusLabel
                text:                   root._statusText
                color:                  root._statusColor === FVTheme.warn ? FVTheme.warnInk : FVTheme.text
                font.bold:              true
                horizontalAlignment:    Text.AlignHCenter
                verticalAlignment:      Text.AlignVCenter
            }
        }

        // Flight mode: shown only. Modes are changed with the switches on the remote.
        Rectangle {
            Layout.alignment:   Qt.AlignVCenter
            implicitHeight:     FVTheme.unit * 1.7
            implicitWidth:      modeRow.implicitWidth + FVTheme.unit * 1.2
            radius:             FVTheme.unit * 0.4
            color:              FVTheme.brand
            visible:            root._vehicle !== null

            Row {
                id:                 modeRow
                anchors.centerIn:   parent
                spacing:            FVTheme.unit * 0.3

                FVIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name:                   "lock"
                    height:                 FVTheme.unit * 0.8
                }

                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   root._vehicle ? root._vehicle.flightMode.toUpperCase() : ""
                    color:                  FVTheme.text
                    font.bold:              true
                }
            }
        }

        Item { Layout.fillWidth: true }

        Row {
            Layout.alignment:   Qt.AlignVCenter
            spacing:            FVTheme.unit * 0.25
            visible:            root._vehicle !== null

            FVIcon {
                anchors.verticalCenter: parent.verticalCenter
                name:                   "gps"
                height:                 FVTheme.unit * 1.1
                color:                  root._gpsLock >= 3 ? FVTheme.text : FVTheme.warn
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   root._gpsCount
                color:                  root._gpsLock >= 3 ? FVTheme.text : FVTheme.warn
                font.bold:              true
            }
        }

        Row {
            Layout.alignment:   Qt.AlignVCenter
            spacing:            FVTheme.unit * 0.25
            visible:            root._vehicle !== null

            // Remote control signal, four bars
            Row {
                anchors.bottom: rcLabel.baseline
                spacing:        FVTheme.unit * 0.1

                Repeater {
                    model: 4

                    Rectangle {
                        anchors.bottom: parent.bottom
                        width:          FVTheme.unit * 0.22
                        height:         FVTheme.unit * (0.35 + index * 0.22)
                        radius:         width / 3
                        color:          root._rssiValid && root._rssi > index * 25 ? FVTheme.text : FVTheme.plateLine
                    }
                }
            }

            QGCLabel {
                id:         rcLabel
                text:       qsTr("RC")
                color:      FVTheme.text
                font.bold:  true
            }
        }

        Row {
            Layout.alignment:   Qt.AlignVCenter
            spacing:            FVTheme.unit * 0.3
            visible:            root._battery !== null

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:                  FVTheme.unit * 1.4
                height:                 FVTheme.unit * 0.8
                radius:                 FVTheme.unit * 0.15
                color:                  "transparent"
                border.width:           2
                border.color:           FVTheme.text

                Rectangle {
                    x:      3
                    y:      3
                    height: parent.height - 6
                    width:  isNaN(root._batteryPercent) ? 0 : Math.max(0, (parent.width - 6) * Math.min(100, root._batteryPercent) / 100)
                    radius: 1
                    color:  root._batteryColor()
                }
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   isNaN(root._batteryPercent) ? "--" : qsTr("%1%").arg(Math.round(root._batteryPercent))
                color:                  root._batteryColor()
                font.bold:              true
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   qsTr("%1 min").arg(Math.floor(root._batterySeconds / 60))
                color:                  FVTheme.textDim
                visible:                !isNaN(root._batterySeconds) && root._batterySeconds > 0
            }
        }

        FVLivePill {
            Layout.alignment:   Qt.AlignVCenter
        }

        AbstractButton {
            Layout.alignment:   Qt.AlignVCenter
            implicitWidth:      FVTheme.unit * 2
            implicitHeight:     implicitWidth
            focusPolicy:        Qt.NoFocus
            onClicked:          mainWindow.showSettingsTool()

            background: Rectangle {
                radius: width / 2
                color:  parent.pressed ? FVTheme.plateLine : FVTheme.chip
            }

            contentItem: Item {
                FVIcon {
                    anchors.centerIn:   parent
                    name:               "gear"
                    height:             FVTheme.unit * 1.15
                }
            }
        }
    }

    Component {
        id: messagesPage

        ToolIndicatorPage {
            contentComponent: Component {
                ColumnLayout {
                    spacing: ScreenTools.defaultFontPixelHeight / 2

                    QGCLabel {
                        text:       qsTr("Messages from the drone")
                        font.bold:  true
                    }

                    // Plain list: links in messages (e.g. to parameters) are not followed in customer mode.
                    TextArea {
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelWidth * 50
                        readOnly:               true
                        textFormat:             TextEdit.RichText
                        wrapMode:               TextEdit.Wrap
                        padding:                0
                        color:                  QGroundControl.globalPalette.text
                        placeholderText:        qsTr("No messages")
                        placeholderTextColor:   QGroundControl.globalPalette.text
                        text: {
                            const vehicle = QGroundControl.multiVehicleManager.activeVehicle
                            if (!vehicle) {
                                return ""
                            }
                            const pal = QGroundControl.globalPalette
                            return vehicle.formattedMessages
                                .replace(/<#[EI]>/g, "color: " + pal.warningText + ";")
                                .replace(/<#N>/g, "color: " + pal.text + ";")
                        }
                    }
                }
            }
        }
    }
}
