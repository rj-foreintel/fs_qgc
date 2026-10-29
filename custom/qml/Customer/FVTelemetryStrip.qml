import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Bottom telemetry strip of the customer Fly view: height, distance from home, speed, climb
// rate and flight time, in the units chosen in Settings > General.
Rectangle {
    id: root

    height: FVTheme.unit * 3.6
    radius: FVTheme.radius
    color:  FVTheme.plate

    property var _vehicle: QGroundControl.multiVehicleManager.activeVehicle

    function _value(fact) {
        if (!_vehicle || !fact || isNaN(fact.rawValue)) {
            return "--"
        }
        return fact.valueString
    }

    RowLayout {
        anchors.fill:           parent
        anchors.leftMargin:     FVTheme.margin
        anchors.rightMargin:    FVTheme.margin
        spacing:                0

        Repeater {
            model: [
                { label: qsTr("HEIGHT"),      fact: root._vehicle ? root._vehicle.altitudeRelative : null },
                { label: qsTr("DISTANCE"),    fact: root._vehicle ? root._vehicle.distanceToHome : null },
                { label: qsTr("SPEED"),       fact: root._vehicle ? root._vehicle.groundSpeed : null },
                { label: qsTr("CLIMB"),       fact: root._vehicle ? root._vehicle.climbRate : null },
                { label: qsTr("FLIGHT TIME"), fact: root._vehicle ? root._vehicle.flightTime : null }
            ]

            Column {
                id: cell

                required property var modelData

                Layout.fillWidth:   true
                Layout.alignment:   Qt.AlignVCenter
                spacing:            0

                QGCLabel {
                    anchors.horizontalCenter:   parent.horizontalCenter
                    text:                       cell.modelData.label
                    color:                      FVTheme.textDim
                    font.pointSize:             FVTheme.smallFont
                    font.bold:                  true
                }

                Row {
                    anchors.horizontalCenter:   parent.horizontalCenter
                    spacing:                    FVTheme.unit * 0.2

                    QGCLabel {
                        id:             valueLabel
                        text:           root._value(cell.modelData.fact)
                        color:          FVTheme.text
                        font.bold:      true
                        font.pointSize: FVTheme.largeFont * 1.15
                    }

                    QGCLabel {
                        anchors.baseline:   valueLabel.baseline
                        text:               cell.modelData.fact ? cell.modelData.fact.units : ""
                        color:              FVTheme.text
                        font.pointSize:     FVTheme.smallFont
                        visible:            valueLabel.text !== "--" && text !== "" && text !== "hh:mm:ss"
                    }
                }
            }
        }
    }
}
