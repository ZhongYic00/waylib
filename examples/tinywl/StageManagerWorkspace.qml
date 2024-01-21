// Copyright (C) 2023 Rubbish <>.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Waylib.Server

Item {
    id: root

    function getSurfaceItemFromWaylandSurface(surface) {
        let finder = function(props) {
            if (!props.waylandSurface)
                return false
            // surface is WToplevelSurface or WSurfce
            if (props.waylandSurface === surface || props.waylandSurface.surface === surface)
                return true
        }

        let toplevel = QmlHelper.xdgSurfaceManager.getIf(toplevelComponent, finder)
        if (toplevel) {
            return {
                shell: toplevel,
                item: toplevel,
                type: "toplevel"
            }
        }

        let popup = QmlHelper.xdgSurfaceManager.getIf(popupComponent, finder)
        if (popup) {
            return {
                shell: popup,
                item: popup.xdgSurface,
                type: "popup"
            }
        }

        let layer = QmlHelper.layerSurfaceManager.getIf(layerComponent, finder)
        if (layer) {
            return {
                shell: layer,
                item: layer.surfaceItem,
                type: "layer"
            }
        }

        let xwayland = QmlHelper.xwaylandSurfaceManager.getIf(xwaylandComponent, finder)
        if (xwayland) {
            return {
                shell: xwayland,
                item: xwayland,
                type: "xwayland"
            }
        }

        return null
    }

    property real ratio: 3 / 2
    Rectangle {
        anchors.fill: parent
        color: !regionBackground.checked?"transparent":"grey"
        RowLayout {
            anchors.fill: parent
            Component.onCompleted: console.error(parent, parent.implicitHeight,
                                                 height, width)
            Slider {
                id: slider
                from: 0
                to: 90
                visible: false
            }
            Rectangle {
                color: !regionBackground.checked?"transparent":"yellow"
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                Layout.fillWidth: true
                Layout.maximumWidth: parent.width * 0.1
                Column {
                    id: col
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    height: (children.length-1) * width / ratio
                    spacing: 10
                    onYChanged: console.log('col',x,y,width,height)

                    ListModel {
                        id: dockmodel
                        function removeSurface(surface) {
                            for (var i = 0; i < dockmodel.count; i++) {
                                if (dockmodel.get(i).source === surface) {
                                    dockmodel.remove(i);
                                    break;
                                }
                            }
                        }
                    }

                    move: Transition{
                        NumberAnimation {
                            properties: "x,y"
                            easing.type: Easing.InOutCubic
                            duration: 1000
                        }
                    }
                    Behavior on height {
                        NumberAnimation {
                            duration: 1000
                        }
                    }

                    Repeater {
                        id: pseudo
                        model: 1
                        Component.onCompleted: console.log('repeater', x, y,
                                                           width, height)

                        Item {
                            width: col.width
                            height: width / ratio
                            onHeightChanged: console.log('boxrect', height,
                                                         x, y, index)
                            RoundedImage {
                                id: appicon
                                width: col.width / 4
                                height: width
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                radius: 5
                                src: "file:///home/zyc/Pictures/member.bilibili.com_york_up-milestone1.png"
                                z: 10
                            }

                            Repeater {
                                model: 1
                                Rectangle {
                                    color: !regionBackground.checked?"transparent":"red"
                                    width: col.width
                                    height: width / ratio
                                    antialiasing: true
                                    radius: 5
                                    Image {
                                        source: "file:///home/zyc/Pictures/whu-logo.png"
                                        anchors.fill: parent
                                    }
                                    Rectangle {
                                        // hover shadow
                                        color: Qt.rgba(0, 0, 0, .1)
                                        anchors.fill: parent
                                        visible: hvd.hovered
                                    }
                                    HoverHandler {
                                        id: hvd
                                        //                                        onHoveredChanged: console.log('hvd')
                                    }
                                    TapHandler {
                                        onTapped: {
                                            console.log('tapped')
                                        }
                                    }

                                    clip: false
                                    function mtxTranslate(x, y, z) {
                                        return Qt.matrix4x4(1, 0, 0, x, 0, 1,
                                                            0, y, 0, 0, 1, z,
                                                            0, 0, 0, 1)
                                    }

                                    function myTransform(val) {
                                        var toCenter = mtxTranslate(
                                                    -x,
                                                    //                                                    parent.height / 2 - y - height / 2,
                                                    (col.height / 2 - parent.y - height / 2),
                                                    //                                                    height / 2,
                                                    0)
                                        var revTranslate = mtxTranslate(
                                                    x,
                                                    //                                                    -(parent.height / 2 - y - height / 2),
                                                    -(col.height / 2 - parent.y - height / 2),
                                                    //                                                    -height / 2,
                                                    0)
                                        var proj = Qt.matrix4x4(
                                                    1, 0, 0, 0, 0, 1, 0, 0,
                                                    0, 0, 1, -val,
                                                    0.001, 0, 0, 1)
                                        // console.log('mytransform', height, x,
                                        //             y, toCenter.times(
                                        //                 proj).times(
                                        //                 revTranslate), proj)
                                        return toCenter.times(proj).times(
                                                    revTranslate)
                                    }

                                    property var coverTransform: myTransform(
                                                                     slider.value)

                                    z: 1

                                    transform: [
                                        Matrix4x4 {
                                            matrix: coverTransform
                                        }
                                    ]
                                    onWidthChanged: console.log(x, y, z,
                                                                width, height,
                                                                'transform',
                                                                coverTransform)
                                }
                            }
                        }
                    }

                    Repeater {
                        id: rpter
                        model: dockmodel
                        Component.onCompleted: console.log('repeater', x, y, dockmodel.count,
                                                           width, height)
                        property var currentItem
                        function setCurrent(item,thumb){
                            if(currentItem){
                                console.log('prev',currentItem.item.source,currentItem.item.source.enabled)
                                currentItem.item.source.z=0
                                currentItem.item.source.enabled=false
                                // currentItem.item.source.layer.enabled=true
                                // currentItem.item.source.visible=false
                                currentItem.thb.hideSource=true
                                currentItem.item.visible=true
                                console.log('prev',currentItem.item.source,currentItem.item.source.enabled)
                            }
                            item.visible=false
                            item.source.z=10
                            item.source.enabled=true
                            // item.source.visible=true
                            // item.source.layer.enable=false
                            thumb.hideSource=false
                            rpter.currentItem={item:item,thb:thumb}
                        }
                        Item {
                            width: col.width
                            height: width / ratio
                            onHeightChanged: console.log('boxrect', height,
                                                         x, y)
                            onVisibleChanged: console.log('dockitem',dockitem,visible)
                            RoundedImage {
                                id: appicon
                                width: col.width / 4
                                height: width
                                anchors.left: parent.left
                                anchors.bottom: parent.bottom
                                radius: 5
                                src: "file:///home/zyc/Pictures/member.bilibili.com_york_up-milestone1.png"
                                z: 10
                            }
                            id: dockitem
                            required property var source

                            Repeater {
                                model: 1
                                Rectangle {
                                    color: !regionBackground.checked?"transparent":"red"
                                    width: col.width
                                    height: width / ratio
                                    antialiasing: true
                                    radius: 5
                                    ShaderEffectSource {
                                        id: thumb
                                        anchors.fill: parent
                                        sourceItem: dockitem.source
                                        smooth: true
                                        hideSource: true
                                        Component.onCompleted:{
                                            console.log('thumb completed')
                                            rpter.setCurrent(dockitem,thumb)
                                        }
                                        Component.onDestruction:{
                                            if(rpter.currentItem?.thb==thumb){
                                                rpter.currentItem=null
                                            }
                                        }
                                        visible: false
                                    }
                                    MultiEffect {
                                        anchors.fill: parent
                                        source: thumb
                                        shadowEnabled: true
                                        autoPaddingEnabled: true
                                    }
                                    Rectangle {
                                        // hover shadow
                                        color: Qt.rgba(0, 0, 0, .1)
                                        anchors.fill: parent
                                        visible: hvd.hovered
                                    }
                                    HoverHandler {
                                        id: hvd
                                        //                                        onHoveredChanged: console.log('hvd')
                                    }
                                    TapHandler {
                                        onTapped: {
                                            console.log('tapped',dockitem.source,thumb.sourceItem)
                                            rpter.setCurrent(dockitem,thumb)
                                        }
                                    }

                                    clip: false
                                    function mtxTranslate(x, y, z) {
                                        return Qt.matrix4x4(1, 0, 0, x, 0, 1,
                                                            0, y, 0, 0, 1, z,
                                                            0, 0, 0, 1)
                                    }

                                    function myTransform(val) {
                                        var x2z = Qt.matrix4x4(1, 0, 0, 0,
                                                               0, 1, 0, 0,
                                                               0.1, 0, 1, 0,
                                                               0.5, 0, 0, 1)
                                        var toCenter = mtxTranslate(
                                                    -x,
                                                    //                                                    parent.height / 2 - y - height / 2,
                                                    (col.height / 2 - parent.y - height / 2),
                                                    //                                                    height / 2,
                                                    0)
                                        var revTranslate = mtxTranslate(
                                                    x,
                                                    //                                                    -(parent.height / 2 - y - height / 2),
                                                    -(col.height / 2 - parent.y - height / 2),
                                                    //                                                    -height / 2,
                                                    0)
                                        var proj = Qt.matrix4x4(
                                                    1, 0, 0, 0, 0, 1, 0, 0,
                                                    0, 0, 1, 0,
                                                    0.001, 0, 0, 1)
                                        // console.log('mytransform', height, x,
                                        //             y, toCenter.times(
                                        //                 proj).times(
                                        //                 revTranslate), proj)
                                        return toCenter.times(proj).times(
                                                    revTranslate)
                                    }

                                    property var coverTransform: myTransform(
                                                                     slider.value)

                                    z: 1

                                    transform: [
                                        Matrix4x4 {
                                            matrix: coverTransform
                                        }
                                    ]
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                color: !regionBackground.checked?"transparent":"blue"
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                Layout.fillWidth: true
                // RoundedImage {
                //     src: "file:///home/zyc/Pictures/ScreenShots/截图录屏_dde-desktop_20200909201013.png"
                //     anchors.fill: parent
                //     anchors.margins: 50
                // }
                Item {
                    anchors.fill: parent
                    anchors.margins: 50
                    // currentIndex: 0

                    DynamicCreatorComponent {
                        id: toplevelComponent
                        creator: QmlHelper.xdgSurfaceManager
                        chooserRole: "type"
                        chooserRoleValue: "toplevel"
                        autoDestroy: false

                        onObjectRemoved: function (obj) {
                            toplevelComponent.destroyObject(obj)
                        }

                        // TODO: Support server decoration
                        XdgSurface {
                            id: toplevelSurfaceItem
                            // property var doDestroy: helper.doDestroy
                            // property var cancelMinimize: helper.cancelMinimize
                            property int outputCounter: 0
                            enabled: false
                            layer.live: true
                            anchors.fill: parent
                            resizeMode: SurfaceItem.SizeToSurface

                            OutputLayoutItem {
                                anchors.fill: parent
                                layout: QmlHelper.layout

                                onEnterOutput: function(output) {
                                    waylandSurface.surface.enterOutput(output)
                                    Helper.onSurfaceEnterOutput(waylandSurface, toplevelSurfaceItem, output)
                                    outputCounter++

                                    if (outputCounter == 1) {
                                        let outputDelegate = output.OutputItem.item
                                        toplevelSurfaceItem.x = outputDelegate.x
                                                + Helper.getLeftExclusiveMargin(waylandSurface)
                                                + 10
                                        toplevelSurfaceItem.y = outputDelegate.y
                                                + Helper.getTopExclusiveMargin(waylandSurface)
                                                + 10
                                    }
                                }
                                onLeaveOutput: function(output) {
                                    waylandSurface.surface.leaveOutput(output)
                                    Helper.onSurfaceLeaveOutput(waylandSurface, toplevelSurfaceItem, output)
                                    outputCounter--
                                }
                            }

                            // StackToplevelHelper {
                            //     id: helper
                            //     surface: toplevelSurfaceItem
                            //     waylandSurface: toplevelSurfaceItem.waylandSurface
                            //     dockModel: dockmodel
                            //     creator: toplevelComponent
                            // }
                            Component.onCompleted: {
                                dockmodel.append({source: toplevelSurfaceItem})
                            }
                            Component.onDestruction: {
                                dockmodel.removeSurface(toplevelSurfaceItem)
                            }
                        }
                    }

                    DynamicCreatorComponent {
                        id: popupComponent
                        creator: QmlHelper.xdgSurfaceManager
                        chooserRole: "type"
                        chooserRoleValue: "popup"

                        Popup {
                            id: popup

                            required property WaylandXdgSurface waylandSurface
                            property string type

                            property alias xdgSurface: popupSurfaceItem
                            property var parentItem: root.getSurfaceItemFromWaylandSurface(waylandSurface.parentSurface)

                            parent: parentItem ? parentItem.item : root
                            visible: parentItem && parentItem.item.effectiveVisible
                                    && waylandSurface.surface.mapped && waylandSurface.WaylandSocket.rootSocket.enabled
                            x: {
                                let retX = 0 // X coordinate relative to parent
                                let minX = 0
                                let maxX = root.width - xdgSurface.width
                                if (!parentItem) {
                                    retX = popupSurfaceItem.implicitPosition.x
                                    if (retX > maxX)
                                        retX = maxX
                                    if (retX < minX)
                                        retX = minX
                                } else {
                                    retX = popupSurfaceItem.implicitPosition.x / parentItem.item.surfaceSizeRatio + parentItem.item.contentItem.x
                                    let parentX = parent.mapToItem(root, 0, 0).x
                                    if (retX + parentX > maxX) {
                                        if (parentItem.type === "popup")
                                            retX = retX - xdgSurface.width - parent.width
                                        else
                                            retX = maxX - parentX
                                    }
                                    if (retX + parentX < minX)
                                        retX = minX - parentX
                                }
                                return retX
                            }
                            y: {
                                let retY = 0 // Y coordinate relative to parent
                                let minY = 0
                                let maxY = root.height - xdgSurface.height
                                if (!parentItem) {
                                    retY = popupSurfaceItem.implicitPosition.y
                                    if (retY > maxY)
                                        retY = maxY
                                    if (retY < minY)
                                        retY = minY
                                } else {
                                    retY = popupSurfaceItem.implicitPosition.y / parentItem.item.surfaceSizeRatio + parentItem.item.contentItem.y
                                    let parentY = parent.mapToItem(root, 0, 0).y
                                    if (retY + parentY > maxY)
                                        retY = maxY - parentY
                                    if (retY + parentY < minY)
                                        retY = minY - parentY
                                }
                                return retY
                            }
                            padding: 0
                            background: null
                            closePolicy: Popup.CloseOnPressOutside

                            XdgSurface {
                                id: popupSurfaceItem
                                waylandSurface: popup.waylandSurface

                                OutputLayoutItem {
                                    anchors.fill: parent
                                    layout: QmlHelper.layout

                                    onEnterOutput: function(output) {
                                        waylandSurface.surface.enterOutput(output)
                                        Helper.onSurfaceEnterOutput(waylandSurface, popupSurfaceItem, output)
                                    }
                                    onLeaveOutput: function(output) {
                                        waylandSurface.surface.leaveOutput(output)
                                        Helper.onSurfaceLeaveOutput(waylandSurface, popupSurfaceItem, output)
                                    }
                                }
                            }

                            onClosed: {
                                if (waylandSurface)
                                waylandSurface.surface.unmap()
                            }
                        }
                    }

                    DynamicCreatorComponent {
                        id: xwaylandComponent
                        creator: QmlHelper.xwaylandSurfaceManager
                        autoDestroy: false

                        onObjectRemoved: function (obj) {
                            toplevelComponent.destroyObject(obj)
                        }

                        XWaylandSurfaceItem {
                            id: xwaylandSurfaceItem

                            required property XWaylandSurface waylandSurface
                            // property var doDestroy: helper.doDestroy
                            // property var cancelMinimize: helper.cancelMinimize
                            property var surfaceParent: root.getSurfaceItemFromWaylandSurface(waylandSurface.parentXWaylandSurface)
                            property int outputCounter: 0

                            enabled: false

                            surface: waylandSurface
                            parentSurfaceItem: surfaceParent ? surfaceParent.item : null
                            z: waylandSurface.bypassManager ? 1 : 0 // TODO: make to enum type
                            positionMode: {
                                if (!xwaylandSurfaceItem.effectiveVisible)
                                    return XWaylandSurfaceItem.ManualPosition

                                return (Helper.movingItem === xwaylandSurfaceItem || resizeMode === SurfaceItem.SizeToSurface)
                                        ? XWaylandSurfaceItem.PositionToSurface
                                        : XWaylandSurfaceItem.PositionFromSurface
                            }

                            topPadding: decoration.enable ? decoration.topMargin : 0
                            bottomPadding: decoration.enable ? decoration.bottomMargin : 0
                            leftPadding: decoration.enable ? decoration.leftMargin : 0
                            rightPadding: decoration.enable ? decoration.rightMargin : 0

                            surfaceSizeRatio: {
                                const po = waylandSurface.surface.primaryOutput
                                if (!po)
                                    return 1.0
                                if (bufferScale >= po.scale)
                                    return 1.0
                                return po.scale / bufferScale
                            }

                            onEffectiveVisibleChanged: {
                                if (xwaylandSurfaceItem.effectiveVisible)
                                    xwaylandSurfaceItem.move(XWaylandSurfaceItem.PositionToSurface)
                            }

                            // TODO: ensure the event to WindowDecoration before WSurfaceItem::eventItem on surface's edges
                            // maybe can use the SinglePointHandler?
                            WindowDecoration {
                                id: decoration

                                property bool enable: !waylandSurface.bypassManager
                                                    && waylandSurface.decorationsType !== XWaylandSurface.DecorationsNoBorder

                                anchors.fill: parent
                                z: xwaylandSurfaceItem.contentItem.z - 1
                                visible: enable
                            }

                            OutputLayoutItem {
                                anchors.fill: parent
                                layout: QmlHelper.layout

                                onEnterOutput: function(output) {
                                    if (xwaylandSurfaceItem.waylandSurface.surface)
                                        xwaylandSurfaceItem.waylandSurface.surface.enterOutput(output);
                                    Helper.onSurfaceEnterOutput(waylandSurface, xwaylandSurfaceItem, output)

                                    outputCounter++

                                    if (outputCounter == 1) {
                                        let outputDelegate = output.OutputItem.item
                                        xwaylandSurfaceItem.x = outputDelegate.x
                                                + Helper.getLeftExclusiveMargin(waylandSurface)
                                                + 10
                                        xwaylandSurfaceItem.y = outputDelegate.y
                                                + Helper.getTopExclusiveMargin(waylandSurface)
                                                + 10
                                    }
                                }
                                onLeaveOutput: function(output) {
                                    if (xwaylandSurfaceItem.waylandSurface.surface)
                                        xwaylandSurfaceItem.waylandSurface.surface.leaveOutput(output);
                                    Helper.onSurfaceLeaveOutput(waylandSurface, xwaylandSurfaceItem, output)
                                    outputCounter--
                                }
                            }

                            // StackToplevelHelper {
                            //     id: helper
                            //     surface: xwaylandSurfaceItem
                            //     waylandSurface: xwaylandSurfaceItem.waylandSurface
                            //     dockModel: dockmodel
                            //     creator: xwaylandComponent
                            //     decoration: decoration
                            // }
                            Component.onCompleted: {
                                dockmodel.append({source: toplevelSurfaceItem})
                            }
                            Component.onDestruction: {
                                dockmodel.removeSurface(toplevelSurfaceItem)
                            }
                        }
                    }
                }
            }
        }

    }
    Switch {
        id: regionBackground
        text: "layout region background"
        z: 20
        anchors {
            bottom: parent.bottom
            left: parent.left
            margins: 10
        }
    }
    Item {
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
            }
            width: parent.width
            height: parent.height * 0.1
            HoverHandler {
                id: toppane
            }
            LayoutSelector {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    margins: 10
                }
                HoverHandler {
                    id: selector
                }

                z: 9
                height: 80
                Behavior on y {
                    NumberAnimation {
                        duration: 500
                        onStarted: parent.parent.enabled = false
                        onStopped: parent.parent.enabled = true
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 500
                    }
                }
                y: toppane.hovered
                   || selector.hovered ? 10 : -height + parent.height * 0.02
                opacity: toppane.hovered || selector.hovered ? 1 : 0
            }
        }

                        
    DynamicCreatorComponent {
        id: layerComponent
        creator: QmlHelper.layerSurfaceManager
        autoDestroy: false

        onObjectRemoved: function (obj) {
            obj.doDestroy()
        }

        LayerSurface {
            id: layerSurface
            creator: layerComponent
        }
    }

    DynamicCreatorComponent {
        id: inputPopupComponent
        creator: QmlHelper.inputPopupSurfaceManager

        InputPopupSurface {
            required property InputMethodHelper inputMethodHelper
            required property WaylandInputPopupSurface popupSurface

            id: inputPopupSurface
            surface: popupSurface
            helper: inputMethodHelper
        }
    }
}
