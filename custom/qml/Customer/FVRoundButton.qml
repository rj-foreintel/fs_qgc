import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Round icon button used on the camera rail.
AbstractButton {
    id: control

    property string iconName
    property bool   highlighted:    false
    property real   size:           FVTheme.unit * 2.3

    implicitWidth:  size
    implicitHeight: size
    opacity:        enabled ? 1 : 0.45
    focusPolicy:    Qt.NoFocus

    background: Rectangle {
        radius: width / 2
        color:  control.highlighted ? FVTheme.accent : (control.pressed ? FVTheme.plateLine : FVTheme.chip)
    }

    contentItem: Item {
        FVIcon {
            anchors.centerIn:   parent
            name:               control.iconName
            height:             control.size * 0.5
            color:              control.highlighted ? FVTheme.accentInk : FVTheme.text
        }
    }
}
