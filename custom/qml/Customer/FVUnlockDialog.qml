import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

import ForeView

// Company password prompt for Debug Mode (the full QGroundControl UI).
QGCPopupDialog {
    id:         root
    title:      qsTr("Debug Mode")
    buttons:    Dialog.Cancel | Dialog.Ok

    property string _error

    onAccepted: {
        if (ForeViewMode.lockoutSeconds > 0) {
            preventClose = true
            return
        }
        if (ForeViewMode.unlock(passwordField.text)) {
            return
        }
        passwordField.text = ""
        _error = ForeViewMode.lockoutSeconds > 0 ? "" : qsTr("Wrong password.")
        preventClose = true
    }

    Component.onCompleted: passwordField.forceActiveFocus()

    ColumnLayout {
        width:      ScreenTools.defaultFontPixelWidth * 40
        spacing:    ScreenTools.defaultFontPixelHeight / 2

        QGCLabel {
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            text:               qsTr("For Foreintel engineers. Enter the company password to show all settings and tools.")
        }

        QGCTextField {
            id:                 passwordField
            Layout.fillWidth:   true
            echoMode:           TextInput.Password
            placeholderText:    qsTr("Password")
            enabled:            ForeViewMode.lockoutSeconds === 0
            onAccepted:         root._accept()
            onTextChanged:      root._error = ""
        }

        QGCLabel {
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            color:              QGroundControl.globalPalette.warningText
            visible:            text !== ""
            text:               ForeViewMode.lockoutSeconds > 0
                                    ? qsTr("Too many wrong attempts. Try again in %1 s.").arg(ForeViewMode.lockoutSeconds)
                                    : root._error
        }

        QGCLabel {
            Layout.fillWidth:   true
            wrapMode:           Text.WordWrap
            font.pointSize:     ScreenTools.smallFontPointSize
            text:               qsTr("Debug Mode turns off when the app restarts.")
        }
    }
}
