import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// LIVE (RTMP live streaming) pill for the customer top bar. Same states and Go Live / Stop
// controls as src/Toolbar/LiveStreamIndicator.qml, drawn for the dark customer bar.
// Shown only when Live Streaming is turned on in Settings > Video.
AbstractButton {
    id: control

    visible:        _streamer !== null && QGroundControl.videoManager.gstreamerEnabled && _settings.liveStreamEnabled.rawValue
    implicitHeight: FVTheme.unit * 1.7
    implicitWidth:  liveRow.implicitWidth + FVTheme.unit * 1.2
    focusPolicy:    Qt.NoFocus
    onClicked:      mainWindow.showIndicatorDrawer(liveStreamPage, control)

    property var  _settings:     QGroundControl.settingsManager.videoSettings
    property var  _streamer:     QGroundControl.videoManager.liveStreamer
    property int  _state:        _streamer ? _streamer.state : VideoLiveStreamer.Idle
    property bool _isLive:       _state === VideoLiveStreamer.Live
    property bool _isTrying:     _state === VideoLiveStreamer.WaitingForVideo || _state === VideoLiveStreamer.Connecting || _state === VideoLiveStreamer.Reconnecting
    property bool _isFailed:     _state === VideoLiveStreamer.Failed
    property var  _siyi:         QGroundControl.videoManager.siyiCameraEncoding
    property bool _cameraIsH265: _streamer !== null && _streamer.codec === "H.265"

    function _bitrateText(kbps) {
        if (kbps >= 1000) {
            return qsTr("%1 Mbps").arg((kbps / 1000).toFixed(1))
        }
        return qsTr("%1 kbps").arg(kbps)
    }

    background: Rectangle {
        radius:         height / 2
        color:          control._isLive ? FVTheme.danger : "transparent"
        border.width:   control._isLive ? 0 : 1.5
        border.color:   control._isFailed ? FVTheme.danger : (control._isTrying ? FVTheme.warn : FVTheme.textDim)
    }

    contentItem: Item {
        Row {
            id:                 liveRow
            anchors.centerIn:   parent
            spacing:            FVTheme.unit * 0.3

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:                  FVTheme.unit * 0.5
                height:                 width
                radius:                 width / 2
                color:                  liveLabel.color
                visible:                control._isLive || control._isTrying

                // Blinks while connecting, so it is clear the server is not receiving video yet.
                SequentialAnimation on opacity {
                    running:        control._isTrying
                    loops:          Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            QGCLabel {
                id:             liveLabel
                text:           qsTr("LIVE")
                font.bold:      true
                color:          control._isLive ? FVTheme.text : (control._isFailed ? FVTheme.danger : (control._isTrying ? FVTheme.warn : FVTheme.textDim))
            }
        }
    }

    Component {
        id: liveStreamPage

        ToolIndicatorPage {
            contentComponent: SettingsGroupLayout {
                heading: qsTr("Live Streaming")

                GridLayout {
                    columns:        2
                    columnSpacing:  ScreenTools.defaultFontPixelWidth * 2
                    rowSpacing:     ScreenTools.defaultFontPixelHeight * 0.25

                    QGCLabel { text: qsTr("Status:") }
                    QGCLabel {
                        Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 36
                        wrapMode:               Text.WordWrap
                        text:                   control._streamer && control._streamer.active ? control._streamer.statusText : qsTr("Not streaming")
                    }

                    QGCLabel {
                        text:       qsTr("Video:")
                        visible:    control._streamer && control._streamer.codec !== ""
                    }
                    QGCLabel {
                        text:       control._streamer ? control._streamer.codec : ""
                        visible:    control._streamer && control._streamer.codec !== ""
                    }

                    QGCLabel {
                        text:       qsTr("Upload:")
                        visible:    control._isLive
                    }
                    QGCLabel {
                        text:       control._streamer ? control._bitrateText(control._streamer.bitrateKbps) : ""
                        visible:    control._isLive
                    }
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 44
                    wrapMode:               Text.WordWrap
                    visible:                control._settings.liveStreamUrl.rawValue === ""
                    text:                   qsTr("Set the RTMP URL in Settings > Video before going live.")
                }

                // RTMP needs H.264; SIYI cameras can be switched from H.265 here.
                QGCButton {
                    Layout.fillWidth:   true
                    visible:            control._cameraIsH265 || (control._siyi && control._siyi.busy)
                    enabled:            control._siyi && !control._siyi.busy
                    text:               control._siyi && control._siyi.busy ? qsTr("Switching camera...") : qsTr("Switch Camera to H.264")
                    onClicked:          QGroundControl.videoManager.switchCameraToH264()
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 44
                    wrapMode:               Text.WordWrap
                    visible:                control._siyi && control._siyi.statusText !== "" && !control._isLive
                    text:                   control._siyi ? control._siyi.statusText : ""
                }

                QGCButton {
                    Layout.fillWidth:   true
                    text:               control._streamer && control._streamer.active ? qsTr("Stop Streaming") : qsTr("Go Live")
                    enabled:            control._streamer !== null
                    onClicked: {
                        if (control._streamer.active) {
                            QGroundControl.videoManager.stopLiveStream()
                        } else {
                            QGroundControl.videoManager.startLiveStream()
                        }
                    }
                }
            }
        }
    }
}
