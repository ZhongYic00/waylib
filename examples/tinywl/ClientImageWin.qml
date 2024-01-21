// Copyright (C) 2023 JiDe Zhang <zccrs@live.com>.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick.Controls 2.5
import QtQuick 2.0
import Qt.labs.platform 1.0

ApplicationWindow {
    id: window
    x: 50
    y: 50
    width: 300
    height: 300
    visible: true

    Rectangle {
        anchors.fill: parent
        radius: 20

        property alias animationRunning: ani.running

        Text {
            anchors.centerIn: parent
            text: "Qt Quick in a texture"
            font.pointSize: 40
            color: "white"

            SequentialAnimation on rotation {
                id: ani
                running: true
                PauseAnimation { duration: 1500 }
                NumberAnimation { from: 0; to: 360; duration: 5000; easing.type: Easing.InOutCubic }
                loops: Animation.Infinite
            }
        }
        Image {
            anchors.fill: parent
            source: Qt.application.arguments[3]
            Component.onCompleted: console.info(Qt.application.arguments)
        }

        Column {
            anchors {
                right: parent.right
                bottom: parent.bottom
                margins: 50
            }

            spacing: 10

            Button {
                text: "Quit"
                onClicked: {
                    Qt.quit()
                }
            }
        }
    }

    TextField {
        id: titletxt
        anchors.horizontalCenter: parent.horizontalCenter
        text: `I am a Qt window ${Math.random().toFixed(3)}`
        font.pointSize: 20
    }
}
