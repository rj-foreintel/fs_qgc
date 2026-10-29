import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// GPS in the customer top bar: satellite count, amber until a 3D fix. Tap it for fix type,
// HDOP, VDOP and the drone's position.
AbstractButton {
    id: control

    property var vehicle

    readonly property int   satellites: vehicle ? vehicle.gps.count.rawValue : 0
    readonly property int   lock:       vehicle ? vehicle.gps.lock.rawValue : 0
    readonly property bool  fix3d:      lock >= 3
    readonly property color _color:     fix3d ? FVTheme.text : FVTheme.warn

    function _dop(fact) {
        return fact && !isNaN(fact.rawValue) ? fact.rawValue.toFixed(1) : "--"
    }

    // Rough guide for pilots; lower is better.
    function _hdopQuality(fact) {
        if (!fact || isNaN(fact.rawValue)) {
            return ""
        }
        const v = fact.rawValue
        if (v <= 1.0) return qsTr("excellent")
        if (v <= 2.0) return qsTr("good")
        if (v <= 5.0) return qsTr("fair")
        return qsTr("poor")
    }

    visible:        vehicle !== null && vehicle !== undefined
    implicitHeight: FVTheme.unit * 1.7
    implicitWidth:  gpsRow.implicitWidth
    focusPolicy:    Qt.NoFocus
    onClicked:      mainWindow.showIndicatorDrawer(gpsPage, control)

    contentItem: Item {
        Row {
            id:                 gpsRow
            anchors.centerIn:   parent
            spacing:            FVTheme.unit * 0.25

            FVIcon {
                anchors.verticalCenter: parent.verticalCenter
                name:                   "gps"
                height:                 FVTheme.unit * 1.1
                color:                  control._color
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   control.satellites
                color:                  control._color
                font.bold:              true
            }
        }
    }

    Component {
        id: gpsPage

        ToolIndicatorPage {
            contentComponent: SettingsGroupLayout {
                heading: qsTr("GPS")

                GridLayout {
                    columns:        2
                    columnSpacing:  ScreenTools.defaultFontPixelWidth * 3
                    rowSpacing:     ScreenTools.defaultFontPixelHeight * 0.25

                    QGCLabel { text: qsTr("Satellites") }
                    QGCLabel { text: control.satellites; font.bold: true }

                    QGCLabel { text: qsTr("Fix") }
                    QGCLabel {
                        text:       control.vehicle ? control.vehicle.gps.lock.enumStringValue : "--"
                        color:      control.fix3d ? QGroundControl.globalPalette.text : QGroundControl.globalPalette.colorOrange
                        font.bold:  true
                    }

                    QGCLabel { text: qsTr("HDOP") }
                    QGCLabel {
                        text: control.vehicle ? (control._dop(control.vehicle.gps.hdop) +
                                                 (control._hdopQuality(control.vehicle.gps.hdop) !== "" ? "  (" + control._hdopQuality(control.vehicle.gps.hdop) + ")" : ""))
                                              : "--"
                    }

                    QGCLabel { text: qsTr("VDOP") }
                    QGCLabel { text: control.vehicle ? control._dop(control.vehicle.gps.vdop) : "--" }

                    QGCLabel { text: qsTr("Latitude") }
                    QGCLabel {
                        text: control.vehicle && control.vehicle.coordinate.isValid ? control.vehicle.coordinate.latitude.toFixed(7) : "--"
                    }

                    QGCLabel { text: qsTr("Longitude") }
                    QGCLabel {
                        text: control.vehicle && control.vehicle.coordinate.isValid ? control.vehicle.coordinate.longitude.toFixed(7) : "--"
                    }

                    QGCLabel { text: qsTr("Altitude (MSL)") }
                    QGCLabel {
                        text: control.vehicle && !isNaN(control.vehicle.altitudeAMSL.rawValue)
                              ? control.vehicle.altitudeAMSL.valueString + " " + control.vehicle.altitudeAMSL.units : "--"
                    }
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 46
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    text:                   qsTr("HDOP and VDOP show how well the satellites are spread across the sky (horizontal and vertical). Lower is better: below 1 is excellent, up to 2 is good for flying.")
                }
            }
        }
    }
}
