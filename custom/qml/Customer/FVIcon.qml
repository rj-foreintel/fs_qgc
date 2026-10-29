import QtQuick

import QGroundControl
import QGroundControl.Controls

// One of ForeView's stroke icons (custom/res/foreview/<name>.svg), tinted to any colour.
QGCColoredImage {
    property string name

    width:      height
    height:     FVTheme.unit * 1.3
    source:     name !== "" ? "/ForeView/res/" + name + ".svg" : ""
    color:      FVTheme.text
    fillMode:   Image.PreserveAspectFit
}
