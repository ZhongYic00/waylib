import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 5
    color: "white"
    width: childrenRect.width
    Row {
        anchors {
            top: parent.top
            bottom: parent.bottom
            horizontalCenter: parent.horizontalCenter
            margins: 5
        }
        spacing: 5
        width: childrenRect.width

        Repeater {
            model: [{
                    "t": "LR",
                    "c": [{},{}]
                },{
                    "t": "TD",
                    "c": [{},{}]
                },{
                    "t": "LR",
                    "c": [{
                              "t":"TD",
                              "c":[{},{}]
                          }, {

                          }]
                },{
                    "t": "LR",
                    "c": [{},{
                              "t":"TD",
                              "c":[{},{}]
                          }]
                },{
                    "t": "LR",
                    "c": [{},{},{}]
                },{
                    "t": "TD",
                    "c": [{},{},{}]
                },{
                    "t": "LR",
                    "c":[{},{
                            "t":"TD",
                            "c": [{
                                      "t":"LR",
                                      "c":[{},{}]
                                  }, {
                                    "t":"LR",
                                    "c":[{},{}]
                                  }]
                        }]
                }]
            Rectangle {
                radius: 5
                color: "lightslategrey"
                width: height
                height: parent.height
                property var layout: modelData
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
//                    spacing: 3
//                    ColumnLayout {
//                        Layout.fillHeight: true
//                        Layout.fillWidth: true
//                        Rectangle {
//                            color: "red"
//                            Layout.fillHeight: true
//                            Layout.fillWidth: true
//                        }
//                    }
//                    ColumnLayout {
//                        Layout.fillHeight: true
//                        Layout.fillWidth: true
//                        Rectangle {
//                            color: "red"
//                            Layout.fillHeight: true
//                            Layout.fillWidth: true
//                        }
//                    }
                    Component.onCompleted: {
                        function createChildComponents(parent, config) {
                            console.log('config=',config.c,config.t,'parent=',parent)
                            if (!config.t)
                                return Qt.createQmlObject(`import QtQuick 2.15;import QtQuick.Layouts 1.12; Rectangle {HoverHandler{id:hvd}color:hvd.hovered?Qt.darker("lightgrey",.3):"lightgrey"; Layout.fillWidth:true;Layout.fillHeight:true; radius: 3;}`,parent);
                            let layout=Qt.createQmlObject(`import QtQuick 2.0;import QtQuick.Layouts 1.12; ${config.t=='LR'?"Row":"Column"}Layout {spacing: 3;Layout.fillWidth:true;Layout.fillHeight:true}`, parent);
                            console.log('layout=',layout)
                            for (var i = 0; i < config.c.length; i++) {
                                createChildComponents(layout, config.c[i])
                            }
                        }
                        createChildComponents(this, layout)
                    }
                }
            }
        }
    }
}
