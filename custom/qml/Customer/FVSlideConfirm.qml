import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

// Slide-to-confirm bar for flight actions. Dragging the knob to the far end confirms; letting
// go earlier springs it back. A tap alone never confirms.
Rectangle {
    id: root

    property string text
    property string detail
    property color  knobColor:  FVTheme.accent
    property color  knobInk:    FVTheme.accentInk

    signal confirmed()
    signal cancelled()

    width:          FVTheme.unit * 26
    height:         FVTheme.unit * 3.4
    radius:         height / 2
    color:          FVTheme.plate
    border.width:   1
    border.color:   FVTheme.plateLine

    readonly property real _knobMargin: FVTheme.unit * 0.3
    readonly property real _travel:     track.width - knob.width
    readonly property real _progress:   _travel > 0 ? knob.x / _travel : 0

    onVisibleChanged: knob.x = 0

    Item {
        id:                     track
        anchors.left:           parent.left
        anchors.right:          cancelButton.left
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.margins:        root._knobMargin
        anchors.rightMargin:    FVTheme.unit * 0.5

        Column {
            anchors.left:           parent.left
            anchors.leftMargin:     knob.width + FVTheme.unit * 0.6
            anchors.right:          parent.right
            anchors.verticalCenter: parent.verticalCenter
            opacity:                1 - root._progress
            spacing:                0

            QGCLabel {
                width:          parent.width
                text:           root.text
                color:          FVTheme.text
                font.bold:      true
                font.pointSize: FVTheme.normalFont
                elide:          Text.ElideRight
            }

            QGCLabel {
                width:          parent.width
                text:           root.detail
                color:          FVTheme.textDim
                font.pointSize: FVTheme.smallFont
                elide:          Text.ElideRight
                visible:        text !== ""
            }
        }

        Rectangle {
            id:         knob
            width:      height
            height:     parent.height
            radius:     height / 2
            color:      root.knobColor

            Behavior on x {
                enabled:            !dragArea.drag.active
                NumberAnimation {   duration: 150 }
            }

            FVIcon {
                anchors.centerIn:   parent
                name:               "chevron"
                color:              root.knobInk
                height:             parent.height * 0.5
            }

            MouseArea {
                id:                 dragArea
                anchors.fill:       parent
                drag.target:        knob
                drag.axis:          Drag.XAxis
                drag.minimumX:      0
                drag.maximumX:      root._travel
                preventStealing:    true

                onReleased: {
                    const reachedEnd = root._progress >= 0.9
                    knob.x = 0
                    if (reachedEnd) {
                        root.confirmed()
                    }
                }
            }
        }
    }

    AbstractButton {
        id:                     cancelButton
        anchors.right:          parent.right
        anchors.rightMargin:    root._knobMargin * 2
        anchors.verticalCenter: parent.verticalCenter
        height:                 parent.height - root._knobMargin * 4
        width:                  cancelLabel.implicitWidth + FVTheme.unit * 1.4
        focusPolicy:            Qt.NoFocus
        onClicked:              root.cancelled()

        background: Rectangle {
            radius: height / 2
            color:  cancelButton.pressed ? FVTheme.plateLine : FVTheme.chip
        }

        contentItem: QGCLabel {
            id:                     cancelLabel
            text:                   qsTr("Cancel")
            color:                  FVTheme.text
            font.bold:              true
            horizontalAlignment:    Text.AlignHCenter
            verticalAlignment:      Text.AlignVCenter
        }
    }
}
