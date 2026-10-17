import QtQuick
import QtQuick.Controls

import QGroundControl
import QGroundControl.Controls

import ForeView

// ForeView customer Fly view, drawn over the video (or map) by the FlyView.qml override.
//
// Shows information and offers only safe, confirmed actions:
//  - flight mode is displayed but cannot be changed here (use the remote's switches)
//  - Home, Land, Pause and Mission each need a slide to confirm
//  - camera control goes straight to the SIYI camera
Item {
    id: root

    required property var guidedController
    required property var missionController
    property var pipView

    readonly property real topBarHeight: topBar.height

    /// Opens the list of messages from the drone (used for critical vehicle messages).
    function showMessages() {
        topBar.showMessages()
    }

    property var    _vehicle:       QGroundControl.multiVehicleManager.activeVehicle
    property bool   _armed:         _vehicle ? _vehicle.armed : false
    property bool   _flying:        _vehicle ? _vehicle.flying : false
    property string _flightMode:    _vehicle ? _vehicle.flightMode : ""
    property bool   _commLost:      _vehicle ? _vehicle.vehicleLinkManager.communicationLost : false
    property bool   _canAct:        _vehicle !== null && !_commLost

    // Which actions make sense right now (same rules as QGC's guided actions).
    readonly property bool homeAvailable:  _canAct && _armed && _flying && _vehicle.supports.guidedMode &&
                                            _flightMode !== _vehicle.rtlFlightMode && _flightMode !== _vehicle.smartRTLFlightMode
    readonly property bool landAvailable:  _canAct && _armed && _vehicle.supports.guidedMode && !_vehicle.fixedWing &&
                                            _flightMode !== _vehicle.landFlightMode
    readonly property bool pauseAvailable: _canAct && _armed && _flying && _vehicle.supports.pauseVehicle &&
                                            _flightMode !== _vehicle.pauseFlightMode
    readonly property bool _missionLoaded:  missionController.containsItems
    readonly property bool missionAvailable: {
        if (!_canAct || !_missionLoaded || guidedController._missionActive) {
            return false
        }
        if (_flying) {
            // Continue a mission that was interrupted (e.g. after Pause)
            return missionController.currentMissionIndex < missionController.visualItems.count - 1
        }
        return guidedController._canStartMission
    }

    // ---- Pending action awaiting slide-to-confirm ----
    property string _pendingAction: ""

    function _isAvailable(action) {
        switch (action) {
        case "home":    return homeAvailable
        case "land":    return landAvailable
        case "pause":   return pauseAvailable
        case "mission": return missionAvailable
        }
        return false
    }

    function _confirmText(action) {
        switch (action) {
        case "home":    return qsTr("Slide to return home")
        case "land":    return qsTr("Slide to land here")
        case "pause":   return qsTr("Slide to pause and hover")
        case "mission": return _flying ? qsTr("Slide to continue the mission") : qsTr("Slide to start the mission")
        }
        return ""
    }

    function _confirmDetail(action) {
        switch (action) {
        case "home":    return qsTr("Flies back and lands at the home point")
        case "land":    return qsTr("Lands straight down from where it is")
        case "pause":   return qsTr("Stops and holds its position")
        case "mission": return _flying ? qsTr("Flies the rest of the uploaded mission")
                                       : qsTr("The drone arms, takes off and flies the uploaded mission")
        }
        return ""
    }

    function _execute(action) {
        if (!_vehicle || !_isAvailable(action)) {
            return
        }
        switch (action) {
        case "home":
            _vehicle.guidedModeRTL(false)
            toast.show(qsTr("Returning home"), false)
            break
        case "land":
            _vehicle.guidedModeLand()
            toast.show(qsTr("Landing"), false)
            break
        case "pause":
            _vehicle.pauseVehicle()
            toast.show(qsTr("Paused — holding position"), false)
            break
        case "mission":
            _vehicle.startMission()
            toast.show(_flying ? qsTr("Continuing the mission") : qsTr("Starting the mission"), false)
            break
        }
    }

    function _request(action) {
        _pendingAction = (_pendingAction === action) ? "" : action
    }

    // Drop a pending confirmation that no longer applies (e.g. the drone landed meanwhile).
    onHomeAvailableChanged:    if (_pendingAction === "home" && !homeAvailable) _pendingAction = ""
    onLandAvailableChanged:    if (_pendingAction === "land" && !landAvailable) _pendingAction = ""
    onPauseAvailableChanged:   if (_pendingAction === "pause" && !pauseAvailable) _pendingAction = ""
    onMissionAvailableChanged: if (_pendingAction === "mission" && !missionAvailable) _pendingAction = ""
    onVisibleChanged:           if (!visible) _pendingAction = ""

    // ---- Warning shown under the top bar (most important first) ----
    property var _battery:          _vehicle && _vehicle.batteries.count > 0 ? _vehicle.batteries.get(0) : null
    property real _batteryPercent:  _battery ? _battery.percentRemaining.rawValue : NaN
    property int  _gpsLock:         _vehicle ? _vehicle.gps.lock.rawValue : 0
    property int  _gpsCount:        _vehicle ? _vehicle.gps.count.rawValue : 0

    readonly property var _warning: {
        if (!_vehicle) {
            return null
        }
        if (_commLost) {
            return { text: qsTr("Lost contact with the drone. It will follow its failsafe (usually return home)."), critical: true }
        }
        if (!isNaN(_batteryPercent) && _batteryPercent < 15) {
            return { text: qsTr("Battery critical (%1%). Land or return home now.").arg(Math.round(_batteryPercent)), critical: true }
        }
        if (!isNaN(_batteryPercent) && _batteryPercent < 30 && _flying) {
            return { text: qsTr("Battery low (%1%). Bring the drone home soon.").arg(Math.round(_batteryPercent)), critical: false }
        }
        if (!_armed && _vehicle.prearmError !== "") {
            return { text: qsTr("Cannot arm: %1").arg(_vehicle.prearmError), critical: false }
        }
        if (_gpsLock < 3 && !_flying) {
            return { text: qsTr("Waiting for GPS (%1 satellites)").arg(_gpsCount), critical: false }
        }
        return null
    }

    // ---------------------------------------------------------------------------------------

    FVTopBar {
        id:                 topBar
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.top:        parent.top
        onUnlockRequested:  unlockDialogFactory.open()
    }

    // Which camera view the pilot is looking at
    Rectangle {
        id:                 sensorChip
        anchors.left:       parent.left
        anchors.top:        topBar.bottom
        anchors.margins:    FVTheme.margin
        height:             FVTheme.unit * 1.7
        width:              sensorRow.implicitWidth + FVTheme.unit * 1.2
        radius:             height / 2
        color:              FVTheme.plate
        visible:            ForeViewCamera.connected

        Row {
            id:                 sensorRow
            anchors.centerIn:   parent
            spacing:            FVTheme.unit * 0.35

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:                  FVTheme.unit * 0.45
                height:                 width
                radius:                 width / 2
                color:                  FVTheme.accent
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                color:                  FVTheme.text
                font.bold:              true
                text: {
                    if (!ForeViewCamera.thermalSupported) {
                        return ForeViewCamera.model
                    }
                    return ForeViewCamera.thermalView ? qsTr("%1 · Thermal").arg(ForeViewCamera.model)
                                                      : qsTr("%1 · Colour").arg(ForeViewCamera.model)
                }
            }

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width:                  FVTheme.unit * 0.45
                height:                 width
                radius:                 width / 2
                color:                  FVTheme.record
                visible:                ForeViewCamera.recording
            }

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   qsTr("REC")
                color:                  FVTheme.text
                font.bold:              true
                visible:                ForeViewCamera.recording
            }
        }
    }

    // Warning banner
    Rectangle {
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                topBar.bottom
        anchors.topMargin:          FVTheme.margin
        width:                      warningRow.width + FVTheme.unit * 1.6
        height:                     FVTheme.unit * 2.2
        radius:                     FVTheme.unit * 0.6
        color:                      root._warning && root._warning.critical ? FVTheme.danger : FVTheme.warn
        visible:                    root._warning !== null

        Row {
            id:                 warningRow
            anchors.centerIn:   parent
            spacing:            FVTheme.unit * 0.4

            FVIcon {
                anchors.verticalCenter: parent.verticalCenter
                name:                   "warning"
                height:                 FVTheme.unit * 1.1
                color:                  warningLabel.color
            }

            QGCLabel {
                id:                     warningLabel
                anchors.verticalCenter: parent.verticalCenter
                width:                  Math.min(implicitWidth, root.width - FVTheme.unit * 24)
                text:                   root._warning ? root._warning.text : ""
                color:                  root._warning && root._warning.critical ? FVTheme.text : FVTheme.warnInk
                font.bold:              true
                elide:                  Text.ElideRight
            }
        }
    }

    // Flight actions
    Column {
        id:                 actionColumn
        anchors.left:       parent.left
        anchors.top:        sensorChip.visible ? sensorChip.bottom : topBar.bottom
        anchors.margins:    FVTheme.margin
        spacing:            FVTheme.unit * 0.45

        FVActionButton {
            text:       qsTr("Home")
            iconName:   "home"
            enabled:    root.homeAvailable
            onClicked:  root._request("home")
        }

        FVActionButton {
            text:       qsTr("Land")
            iconName:   "land"
            enabled:    root.landAvailable
            onClicked:  root._request("land")
        }

        FVActionButton {
            text:       qsTr("Pause")
            iconName:   "pause"
            enabled:    root.pauseAvailable
            onClicked:  root._request("pause")
        }

        FVActionButton {
            text:       qsTr("Mission")
            iconName:   "mission"
            fillColor:  FVTheme.go
            enabled:    root.missionAvailable
            onClicked:  root._request("mission")
        }
    }

    // Camera rail, scaled down on short screens so it never runs under the telemetry strip
    FVCameraRail {
        id:                     cameraRail
        anchors.right:          parent.right
        anchors.top:            topBar.bottom
        anchors.margins:        FVTheme.margin
        transformOrigin:        Item.TopRight
        scale:                  Math.min(1, (root.height - topBar.height - FVTheme.margin * 2) / height)
        sheetOpen:              cameraSheet.visible
        onSheetToggleRequested: cameraSheet.visible = !cameraSheet.visible
    }

    FVCameraSheet {
        id:                 cameraSheet
        anchors.right:      cameraRail.left
        anchors.top:        topBar.bottom
        anchors.margins:    FVTheme.margin
        visible:            false
        onCloseRequested:   visible = false
    }

    FVTelemetryStrip {
        id:                     telemetryStrip
        anchors.bottom:         parent.bottom
        anchors.bottomMargin:   FVTheme.margin
        anchors.left:           parent.left
        anchors.leftMargin:     root.pipView && root.pipView.visible ? root.pipView.x + root.pipView.width + FVTheme.margin : FVTheme.margin
        anchors.right:          parent.right
        anchors.rightMargin:    cameraRail.width * cameraRail.scale + FVTheme.margin * 2
    }

    FVSlideConfirm {
        anchors.horizontalCenter:   telemetryStrip.horizontalCenter
        anchors.bottom:             telemetryStrip.top
        anchors.bottomMargin:       FVTheme.margin * 2
        visible:                    root._pendingAction !== ""
        text:                       root._confirmText(root._pendingAction)
        detail:                     root._confirmDetail(root._pendingAction)
        knobColor:                  root._pendingAction === "mission" ? FVTheme.go : FVTheme.accent
        knobInk:                    root._pendingAction === "mission" ? FVTheme.text : FVTheme.accentInk

        onConfirmed: {
            const action = root._pendingAction
            root._pendingAction = ""
            root._execute(action)
        }
        onCancelled: root._pendingAction = ""
    }

    // Short messages: action started, photo saved, camera problems
    Rectangle {
        id:                         toast
        anchors.horizontalCenter:   parent.horizontalCenter
        anchors.top:                topBar.bottom
        anchors.topMargin:          FVTheme.unit * 3.4
        width:                      toastRow.implicitWidth + FVTheme.unit * 1.6
        height:                     FVTheme.unit * 2
        radius:                     height / 2
        color:                      FVTheme.plate
        visible:                    false

        property bool _error: false

        function show(text, error) {
            toastLabel.text = text
            _error = error
            visible = true
            toastTimer.restart()
        }

        Timer {
            id:             toastTimer
            interval:       2500
            onTriggered:    toast.visible = false
        }

        Row {
            id:                 toastRow
            anchors.centerIn:   parent
            spacing:            FVTheme.unit * 0.4

            FVIcon {
                anchors.verticalCenter: parent.verticalCenter
                name:                   toast._error ? "warning" : "check"
                height:                 FVTheme.unit * 1
                color:                  toast._error ? FVTheme.warn : FVTheme.good
            }

            QGCLabel {
                id:                     toastLabel
                anchors.verticalCenter: parent.verticalCenter
                color:                  FVTheme.text
                font.bold:              true
            }
        }
    }

    Connections {
        target: ForeViewCamera
        function onNotice(text, error) { toast.show(text, error) }
    }

    QGCPopupDialogFactory {
        id:                 unlockDialogFactory
        dialogComponent:    unlockDialogComponent
    }

    Component {
        id: unlockDialogComponent
        FVUnlockDialog { }
    }
}
