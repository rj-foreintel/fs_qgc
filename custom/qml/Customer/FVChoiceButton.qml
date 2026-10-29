import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Selectable pill used for camera choices (RGB/IR, thermal colours, thermal range).
AbstractButton {
    id: control

    property string detail
    property bool   selected: false

    implicitWidth:  Math.max(FVTheme.unit * 2.8, labelColumn.implicitWidth + FVTheme.unit * 1.0)
    implicitHeight: detail !== "" ? FVTheme.unit * 2.6 : FVTheme.unit * 1.9
    opacity:        enabled ? 1 : 0.45
    focusPolicy:    Qt.NoFocus

    background: Rectangle {
        radius: FVTheme.unit * 0.5
        color:  control.selected ? FVTheme.accent : (control.pressed ? FVTheme.plateLine : FVTheme.chip)
    }

    contentItem: Item {
        Column {
            id:                 labelColumn
            anchors.centerIn:   parent
            spacing:            0

            QGCLabel {
                anchors.horizontalCenter:   parent.horizontalCenter
                text:                       control.text
                color:                      control.selected ? FVTheme.accentInk : FVTheme.text
                font.bold:                  true
                font.pointSize:             FVTheme.smallFont
            }

            QGCLabel {
                anchors.horizontalCenter:   parent.horizontalCenter
                text:                       control.detail
                color:                      control.selected ? FVTheme.accentInk : FVTheme.textDim
                font.pointSize:             FVTheme.smallFont
                visible:                    text !== ""
            }
        }
    }
}
