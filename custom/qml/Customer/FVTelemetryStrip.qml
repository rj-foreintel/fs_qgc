import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtPositioning

import QGroundControl
import QGroundControl.Controls

// Bottom telemetry strip of the customer Fly view: height, distance from home, speed, climb
// rate and flight time (in the units chosen in Settings > General), and below them the drone's
// latitude / longitude. Tapping the position copies it.
Rectangle {
    id: root

    signal positionCopied()

    height: FVTheme.unit * 4.7
    radius: FVTheme.radius
    color:  FVTheme.plate

    property var _vehicle:      QGroundControl.multiVehicleManager.activeVehicle
    // Flight time has no QML property on Vehicle; stock QGC reads it by name too.
    property var _flightTime:   _vehicle ? _vehicle.getFact("flightTime") : null
    property var _coordinate:   _vehicle ? _vehicle.coordinate : QtPositioning.coordinate()
    property bool _hasPosition: _vehicle !== null && _coordinate.isValid && !(_coordinate.latitude === 0 && _coordinate.longitude === 0)

    function _positionText() {
        return qsTr("%1, %2").arg(_coordinate.latitude.toFixed(6)).arg(_coordinate.longitude.toFixed(6))
    }

    function _value(fact) {
        if (!_vehicle || !fact || isNaN(fact.rawValue)) {
            return "--"
        }
        return fact.valueString
    }

    RowLayout {
        id:                     valuesRow
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         positionRow.top
        anchors.leftMargin:     FVTheme.margin
        anchors.rightMargin:    FVTheme.margin
        spacing:                0

        Repeater {
            model: [
                { label: qsTr("HEIGHT"),      fact: root._vehicle ? root._vehicle.altitudeRelative : null },
                { label: qsTr("DISTANCE"),    fact: root._vehicle ? root._vehicle.distanceToHome : null },
                { label: qsTr("SPEED"),       fact: root._vehicle ? root._vehicle.groundSpeed : null },
                { label: qsTr("CLIMB"),       fact: root._vehicle ? root._vehicle.climbRate : null },
                { label: qsTr("FLIGHT TIME"), fact: root._flightTime }
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

    // Drone position (decimal degrees, WGS84)
    AbstractButton {
        id:                         positionRow
        anchors.bottom:             parent.bottom
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.bottomMargin:       FVTheme.unit * 0.25
        implicitWidth:              positionContent.implicitWidth + FVTheme.unit
        implicitHeight:             FVTheme.unit * 1.3
        focusPolicy:                Qt.NoFocus
        enabled:                    root._hasPosition
        onClicked: {
            QGroundControl.copyToClipboard(root._positionText())
            root.positionCopied()
        }

        contentItem: Item {
            Row {
                id:                 positionContent
                anchors.centerIn:   parent
                spacing:            FVTheme.unit * 0.35

                FVIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    name:                   "gps"
                    height:                 FVTheme.unit * 0.8
                    color:                  FVTheme.textDim
                }

                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   qsTr("LAT")
                    color:                  FVTheme.textDim
                    font.pointSize:         FVTheme.smallFont
                    font.bold:              true
                    visible:                root._hasPosition
                }

                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   root._hasPosition ? root._coordinate.latitude.toFixed(6) : qsTr("No position yet")
                    color:                  root._hasPosition ? FVTheme.text : FVTheme.textDim
                    font.bold:              true
                }

                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   qsTr("LON")
                    color:                  FVTheme.textDim
                    font.pointSize:         FVTheme.smallFont
                    font.bold:              true
                    visible:                root._hasPosition
                }

                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text:                   root._hasPosition ? root._coordinate.longitude.toFixed(6) : ""
                    color:                  FVTheme.text
                    font.bold:              true
                    visible:                root._hasPosition
                }
            }
        }
    }
}
