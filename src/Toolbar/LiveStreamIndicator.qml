import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

// Live streaming (RTMP) indicator. Shows the stream state and opens the Go Live / Stop controls.
// Visible only when Live Streaming is enabled in Settings > Video.
Item {
    id:             control
    width:          pill.width
    anchors.top:    parent.top
    anchors.bottom: parent.bottom

    property bool showIndicator: _streamer !== null && QGroundControl.videoManager.gstreamerEnabled && _settings.liveStreamEnabled.rawValue

    property var  _settings:    QGroundControl.settingsManager.videoSettings
    property var  _streamer:    QGroundControl.videoManager.liveStreamer
    property int  _state:       _streamer ? _streamer.state : VideoLiveStreamer.Idle
    property bool _isLive:      _state === VideoLiveStreamer.Live
    property bool _isTrying:    _state === VideoLiveStreamer.WaitingForVideo || _state === VideoLiveStreamer.Connecting || _state === VideoLiveStreamer.Reconnecting
    property bool _isFailed:    _state === VideoLiveStreamer.Failed
    property var  _siyi:        QGroundControl.videoManager.siyiCameraEncoding
    property bool _cameraIsH265: _streamer !== null && _streamer.codec === "H.265"

    QGCPalette { id: qgcPal }

    function _bitrateText(kbps) {
        if (kbps >= 1000) {
            return qsTr("%1 Mbps").arg((kbps / 1000).toFixed(1))
        }
        return qsTr("%1 kbps").arg(kbps)
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
                        text:                   _streamer && _streamer.active ? _streamer.statusText : qsTr("Not streaming")
                        color:                  control._isFailed ? qgcPal.colorRed : (control._isTrying ? qgcPal.colorOrange : qgcPal.text)
                    }

                    QGCLabel {
                        text:       qsTr("Video:")
                        visible:    _streamer && _streamer.codec !== ""
                    }
                    QGCLabel {
                        text:       _streamer ? _streamer.codec : ""
                        visible:    _streamer && _streamer.codec !== ""
                    }

                    QGCLabel {
                        text:       qsTr("Upload:")
                        visible:    control._isLive
                    }
                    QGCLabel {
                        text:       _streamer ? control._bitrateText(_streamer.bitrateKbps) : ""
                        visible:    control._isLive
                    }
                }

                QGCLabel {
                    Layout.maximumWidth:    ScreenTools.defaultFontPixelWidth * 44
                    wrapMode:               Text.WordWrap
                    visible:                _settings.liveStreamUrl.rawValue === ""
                    text:                   qsTr("Set the RTMP URL in Settings > Video before going live.")
                }

                // SIYI cameras can be switched from H.265 to H.264 from here (RTMP needs H.264).
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
                    text:               _streamer && _streamer.active ? qsTr("Stop Streaming") : qsTr("Go Live")
                    enabled:            _streamer !== null
                    onClicked: {
                        if (_streamer.active) {
                            QGroundControl.videoManager.stopLiveStream()
                        } else {
                            QGroundControl.videoManager.startLiveStream()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id:                     pill
        anchors.verticalCenter: parent.verticalCenter
        height:                 ScreenTools.defaultFontPixelHeight * 1.5
        width:                  pillRow.width + ScreenTools.defaultFontPixelWidth * 1.5
        radius:                 height / 2
        color:                  control._isLive ? qgcPal.colorRed : "transparent"
        border.width:           control._isLive ? 0 : 1
        border.color:           control._isFailed ? qgcPal.colorRed : (control._isTrying ? qgcPal.colorOrange : qgcPal.buttonText)

        Row {
            id:                 pillRow
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelWidth * 0.5

            Rectangle {
                id:                     dot
                anchors.verticalCenter: parent.verticalCenter
                width:                  ScreenTools.defaultFontPixelHeight * 0.5
                height:                 width
                radius:                 width / 2
                color:                  liveText.color
                visible:                control._isLive || control._isTrying

                // Blink while connecting so it is obvious that video is not reaching the server yet.
                SequentialAnimation on opacity {
                    running:    control._isTrying
                    loops:      Animation.Infinite
                    alwaysRunToEnd: true
                    NumberAnimation { to: 0.2; duration: 500 }
                    NumberAnimation { to: 1.0; duration: 500 }
                }
            }

            QGCLabel {
                id:             liveText
                text:           qsTr("LIVE")
                font.bold:      true
                color:          control._isLive ? "white" : (control._isFailed ? qgcPal.colorRed : (control._isTrying ? qgcPal.colorOrange : qgcPal.buttonText))
            }
        }
    }

    QGCMouseArea {
        fillItem:   pill
        onClicked:  mainWindow.showIndicatorDrawer(liveStreamPage, control)
    }
}
