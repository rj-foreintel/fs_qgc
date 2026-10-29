import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Large flight action button on the left of the customer Fly view (Home, Land, Pause, Mission).
AbstractButton {
    id: control

    property string iconName
    property color  fillColor:  FVTheme.plate

    implicitWidth:  FVTheme.unit * 3.8
    implicitHeight: FVTheme.unit * 3.3
    opacity:        enabled ? 1 : 0.45
    focusPolicy:    Qt.NoFocus

    background: Rectangle {
        radius:         FVTheme.radius
        color:          control.fillColor
        border.width:   control.pressed ? 2 : 0
        border.color:   FVTheme.accent
    }

    contentItem: Item {
        Column {
            anchors.centerIn:   parent
            spacing:            FVTheme.unit * 0.15

            FVIcon {
                anchors.horizontalCenter:   parent.horizontalCenter
                name:                       control.iconName
                height:                     FVTheme.unit * 1.35
            }

            QGCLabel {
                anchors.horizontalCenter:   parent.horizontalCenter
                text:                       control.text
                color:                      FVTheme.text
                font.pointSize:             FVTheme.smallFont
                font.bold:                  true
            }
        }
    }
}
