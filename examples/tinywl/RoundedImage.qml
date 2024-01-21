import QtQuick 2.12

//import QtGraphicalEffects 1.0
Item {
    property string src: ""
    property int radius: 20
    clip: true
    Image {
        id: content
        source: src
        anchors.fill: parent
        //        visible: false
    }
    Rectangle {
        id: mask
        radius: parent.radius
        visible: false
        anchors.fill: parent
    }
    //    OpacityMask {
    //        anchors.fill: parent
    //        maskSource: mask
    //        source: content
    //    }
}
