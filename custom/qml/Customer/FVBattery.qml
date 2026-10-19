import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

// Battery in the customer top bar. Tap it for voltage, current, used capacity and remaining %.
//
// Where the numbers come from (ArduPilot):
//  - voltage and current are measured by the flight controller's power module
//  - remaining % is the flight controller's estimate from the mAh used since power-on and
//    BATT_CAPACITY. It assumes the pack was full at power-on, so it can read ~100% on a part-
//    charged pack, and it is not sent at all when BATT_CAPACITY is not set.
//  - the charge state (OK / low / critical) is the flight controller's battery failsafe level,
//    from BATT_LOW_VOLT / BATT_CRT_VOLT (and BATT_LOW_MAH / BATT_CRT_MAH when set).
// So the bar shows voltage by default and takes its colour from the charge state.
AbstractButton {
    id: control

    property var battery

    readonly property real   voltage:        battery ? battery.voltage.rawValue : NaN
    readonly property real   percent:        battery ? battery.percentRemaining.rawValue : NaN
    readonly property int    chargeState:    battery ? battery.chargeState.rawValue : 0

    // MAV_BATTERY_CHARGE_STATE: 0 undefined, 1 OK, 2 low, 3 critical, 4 emergency, 5 failed, 6 unhealthy, 7 charging
    readonly property bool   stateKnown:     chargeState >= 1 && chargeState <= 6
    readonly property bool   isLow:          stateKnown ? chargeState === 2 : (!isNaN(percent) && percent < 30)
    readonly property bool   isCritical:     stateKnown ? chargeState >= 3 : (!isNaN(percent) && percent < 15)

    // 0 percentage, 1 voltage, 2 both (QGC's battery indicator setting; ForeView defaults to voltage)
    readonly property int    _display:       QGroundControl.settingsManager.batteryIndicatorSettings.valueDisplay.rawValue
    readonly property bool   _showVoltage:   _display !== 0 || isNaN(percent)
    readonly property bool   _showPercent:   _display !== 1 && !isNaN(percent)

    readonly property color  levelColor:     isCritical ? FVTheme.danger : (isLow ? FVTheme.warn : (stateKnown || !isNaN(percent) ? FVTheme.good : FVTheme.text))

    function voltageText() {
        return isNaN(voltage) ? "--" : qsTr("%1 V").arg(voltage.toFixed(1))
    }

    function stateText() {
        switch (chargeState) {
        case 1: return qsTr("OK")
        case 2: return qsTr("Low")
        case 3: return qsTr("Critical")
        case 4: return qsTr("Emergency")
        case 5: return qsTr("Failed")
        case 6: return qsTr("Unhealthy")
        case 7: return qsTr("Charging")
        }
        return qsTr("Not reported")
    }

    visible:        battery !== null && battery !== undefined
    implicitHeight: FVTheme.unit * 1.7
    implicitWidth:  batteryRow.implicitWidth
    focusPolicy:    Qt.NoFocus
    onClicked:      mainWindow.showIndicatorDrawer(batteryPage, control)

    contentItem: Item {
        Row {
            id:                 batteryRow
            anchors.centerIn:   parent
            spacing:            FVTheme.unit * 0.3

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:                  FVTheme.unit * 1.4
                height:                 FVTheme.unit * 0.8
                radius:                 FVTheme.unit * 0.15
                color:                  "transparent"
                border.width:           2
                border.color:           FVTheme.text

                // Filled to the remaining % when the flight controller reports it; otherwise a
                // solid block in the charge-state colour.
                Rectangle {
                    x:      3
                    y:      3
                    height: parent.height - 6
                    width:  isNaN(control.percent) ? (control.stateKnown ? parent.width - 6 : 0)
                                                   : Math.max(0, (parent.width - 6) * Math.min(100, control.percent) / 100)
                    radius: 1
                    color:  control.levelColor
                }
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   control.voltageText()
                color:                  control.levelColor
                font.bold:              true
                visible:                control._showVoltage
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   qsTr("%1%").arg(Math.round(control.percent))
                color:                  control._showVoltage ? FVTheme.textDim : control.levelColor
                font.bold:              !control._showVoltage
                visible:                control._showPercent
            }
        }
    }

    Component {
        id: batteryPage

        ToolIndicatorPage {
            contentComponent: SettingsGroupLayout {
                heading: qsTr("Battery")

                GridLayout {
                    columns:        2
                    columnSpacing:  ScreenTools.defaultFontPixelWidth * 3
                    rowSpacing:     ScreenTools.defaultFontPixelHeight * 0.25

                    QGCLabel { text: qsTr("Voltage") }
                    QGCLabel { text: control.voltageText(); font.bold: true }

                    QGCLabel { text: qsTr("Current") }
                    QGCLabel {
                        text: control.battery && !isNaN(control.battery.current.rawValue)
                              ? qsTr("%1 A").arg(control.battery.current.rawValue.toFixed(1)) : "--"
                    }

                    QGCLabel { text: qsTr("Used since power-on") }
                    QGCLabel {
                        text: control.battery && !isNaN(control.battery.mahConsumed.rawValue)
                              ? qsTr("%1 mAh").arg(Math.round(control.battery.mahConsumed.rawValue)) : "--"
                    }

                    QGCLabel { text: qsTr("Remaining (estimate)") }
                    QGCLabel { text: isNaN(control.percent) ? qsTr("Not reported") : qsTr("%1%").arg(Math.round(control.percent)) }

                    QGCLabel { text: qsTr("Time left (estimate)") }
                    QGCLabel {
                        text: control.battery && !isNaN(control.battery.timeRemaining.rawValue) && control.battery.timeRemaining.rawValue > 0
                              ? qsTr("%1 min").arg(Math.floor(control.battery.timeRemaining.rawValue / 60)) : "--"
                    }

                    QGCLabel { text: qsTr("State") }
                    QGCLabel {
                        text:       control.stateText()
                        color:      control.isCritical ? QGroundControl.globalPalette.colorRed
                                                       : (control.isLow ? QGroundControl.globalPalette.colorOrange : QGroundControl.globalPalette.text)
                        font.bold:  control.isLow || control.isCritical
                    }
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 46
                    wrapMode:               Text.WordWrap
                    font.pointSize:         ScreenTools.smallFontPointSize
                    text:                   qsTr("Remaining % and time left are estimated by the flight controller from the mAh used since power-on, assuming the battery was full at power-on. Voltage and State are measured; State follows the flight controller's low and critical battery levels.")
                }

                LabelledFactComboBox {
                    Layout.fillWidth:   true
                    label:              qsTr("Show in top bar")
                    fact:               QGroundControl.settingsManager.batteryIndicatorSettings.valueDisplay
                    indexModel:         false
                }
            }
        }
    }
}
