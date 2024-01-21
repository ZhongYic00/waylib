// Copyright (C) 2023 JiDe Zhang <zccrs@live.com>.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Waylib.Server
import Tinywl

Item {
    id :root

    WaylandServer {
        id: server

        WaylandBackend {
            id: backend

            onOutputAdded: function(output) {
                if (!backend.hasDrm)
                    output.forceSoftwareCursor = true // Test

                Helper.allowNonDrmOutputAutoChangeMode(output)
                QmlHelper.outputManager.add({waylandOutput: output})
                outputManagerV1.newOutput(output)
            }
            onOutputRemoved: function(output) {
                output.OutputItem.item.invalidate()
                QmlHelper.outputManager.removeIf(function(prop) {
                    return prop.waylandOutput === output
                })
                outputManagerV1.removeOutput(output)
            }
            onInputAdded: function(inputDevice) {
                seat0.addDevice(inputDevice)
            }
            onInputRemoved: function(inputDevice) {
                seat0.removeDevice(inputDevice)
            }
            Component.onCompleted:{
                console.log('server ready',backend)
            }
        }

        WaylandCompositor {
            id: compositor

            backend: backend
        }

        XdgShell {
            id: shell

            onSurfaceAdded: function(surface) {
                let type = surface.isPopup ? "popup" : "toplevel"
                QmlHelper.xdgSurfaceManager.add({type: type, waylandSurface: surface})
            }
            onSurfaceRemoved: function(surface) {
                QmlHelper.xdgSurfaceManager.removeIf(function(prop) {
                    return prop.waylandSurface === surface
                })
            }
        }

        LayerShell {
            id: layerShell

            onSurfaceAdded: function(surface) {
                QmlHelper.layerSurfaceManager.add({waylandSurface: surface})
            }
            onSurfaceRemoved: function(surface) {
                QmlHelper.layerSurfaceManager.removeIf(function(prop) {
                    return prop.waylandSurface === surface
                })
            }
        }

        Seat {
            id: seat0
            name: "seat0"
            cursor: Cursor {
                id: cursor1

                layout: QmlHelper.layout
            }

            eventFilter: Helper
            keyboardFocus: Helper.getFocusSurfaceFrom(renderWindow.activeFocusItem)
        }

        GammaControlManager {
            onGammaChanged: function(output, gamma_control, ramp_size, r, g, b) {
                if (!output.setGammaLut(ramp_size, r, g, b)) {
                    sendFailedAndDestroy(gamma_control);
                };
            }
        }

        OutputManager {
            id: outputManagerV1

            onRequestTestOrApply: function(config, onlyTest) {
                var states = outputManagerV1.stateListPending()
                var ok = true

                for (const i in states) {
                    let output = states[i].output
                    output.enable(states[i].enabled)
                    if (states[i].enabled) {
                        if (states[i].mode)
                            output.setMode(states[i].mode)
                        else
                            output.setCustomMode(states[i].custom_mode_size,
                                                  states[i].custom_mode_refresh)

                        output.enableAdaptiveSync(states[i].adaptive_sync_enabled)
                        if (!onlyTest) {
                            let outputDelegate = output.OutputItem.item
                            outputDelegate.setTransform(states[i].transform)
                            outputDelegate.setScale(states[i].scale)
                            outputDelegate.x = states[i].x
                            outputDelegate.y = states[i].y
                        }
                    }

                    if (onlyTest) {
                        ok &= output.test()
                        output.rollback()
                    } else {
                        ok &= output.commit()
                        if (ok)
                            updateRenderWindowSize()
                    }
                }
                outputManagerV1.sendResult(config, ok)
            }

            function updateRenderWindowSize() {
                var states = outputManagerV1.stateListPending()
                var maxX = 0, maxY = 0
                for (const i in states) {
                    let outputDelegate = states[i].output.OutputItem.item
                    maxX = Math.max(maxX, outputDelegate.x + outputDelegate.width)
                    maxY = Math.max(maxY, outputDelegate.y + outputDelegate.height)
                }
                outputLayout.xRange = maxX
                outputLayout.yRange = maxY
            }
        }

        CursorShapeManager { }

        WaylandSocket {
            id: masterSocket

            freezeClientWhenDisable: false

            onEnabledChanged: {
                console.warn(`waylandsock enabled=${enabled}`)
            }

            Component.onCompleted: {
                console.info("Listing on:", socketFile)
                console.log("demo start status:", Helper.startDemoClient(socketFile))
                console.log("demo start status:", Helper.startDemoClient(socketFile))
                console.log("demo start status:", Helper.startDemoClient(socketFile))
                console.log("demo start status:", Helper.startDemoClient(socketFile,"weston"))
                console.log("demo start status:", Helper.startDemoClient(socketFile,"qml /home/zyb/Coding/Qt/DDM/treeland/waylib/examples/tinywl/ClientImageWin.qml -- 'file:///home/zyc/Pictures/ScreenShots/截图录屏_dde-desktop_20200909201013.png'"))
                console.log("demo start status:", Helper.startDemoClient(socketFile,"cd /home/zyc/Github/QtQuick-DTK-style && ./build/linux/x86_64/debug/example-cpp -platform wayland"))
            }
        }

        // TODO: add attached property for XdgSurface
        XdgDecorationManager {
            id: decorationManager
        }

        InputMethodManagerV2 {
            id: inputMethodManagerV2
        }

        TextInputManagerV1 {
            id: textInputManagerV1
        }

        TextInputManagerV3 {
            id: textInputManagerV3
        }

        VirtualKeyboardManagerV1 {
            id: virtualKeyboardManagerV1
        }

        XWayland {
            compositor: compositor.compositor
            seat: seat0.seat
            lazy: false

            onReady: masterSocket.addClient(client())

            onSurfaceAdded: function(surface) {
                QmlHelper.xwaylandSurfaceManager.add({waylandSurface: surface})
            }
            onSurfaceRemoved: function(surface) {
                QmlHelper.xwaylandSurfaceManager.removeIf(function(prop) {
                    return prop.waylandSurface === surface
                })
            }
        }
    }

    InputMethodHelper {
        id: inputMethodHelperSeat0
        seat: seat0
        textInputManagerV1: textInputManagerV1
        textInputManagerV3: textInputManagerV3
        inputMethodManagerV2: inputMethodManagerV2
        virtualKeyboardManagerV1: virtualKeyboardManagerV1
        activeFocusItem: renderWindow.activeFocusItem.parent
        onInputPopupSurfaceV2Added: function (surface) {
            QmlHelper.inputPopupSurfaceManager.add({ popupSurface: surface, inputMethodHelper: inputMethodHelperSeat0 })
        }
        onInputPopupSurfaceV2Removed: function (surface) {
            QmlHelper.inputPopupSurfaceManager.removeIf(function (prop) {
                return prop.popupSurface === surface
            })
        }
    }

    OutputRenderWindow {
        id: renderWindow

        compositor: compositor
        width: outputLayout.xRange + outputLayout.x
        height: outputLayout.yRange + outputLayout.y

        EventJunkman {
            anchors.fill: parent
        }

        Item {
            id: outputLayout

            property int xRange: 0
            property int yRange: 0

            DynamicCreatorComponent {
                id: outputDelegateCreator
                creator: QmlHelper.outputManager

                OutputDelegate {
                    property real topMargin: topbar.height
                    waylandCursor: cursor1

                    Component.onCompleted: {
                        x = outputLayout.xRange
                        y = 0
                        outputLayout.xRange += width
                        if (outputLayout.yRange < height)
                            outputLayout.yRange = height
                    }


                }
            }
        }

        ColumnLayout {
            anchors.fill: parent

            TabBar {
                id: topbar

                Layout.fillWidth: true

                TabButton {
                    text: qsTr("Stack Layout")
                    onClicked: {
                        decorationManager.mode = XdgDecorationManager.PreferClientSide
                    }
                }
                TabButton {
                    text: qsTr("Tiled Layout")
                    onClicked: {
                        decorationManager.mode = XdgDecorationManager.PreferServerSide
                    }
                }
                TabButton {
                    text: qsTr("StageManager Layout")
                    onClicked: {
                        decorationManager.mode = XdgDecorationManager.PreferServerSide
                    }
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                StackWorkspace {
                    visible: topbar.currentIndex === 0
                    anchors.fill: parent
                }

                TiledWorkspace {
                    visible: topbar.currentIndex === 1
                    anchors.fill: parent
                }
                StageManagerWorkspace {
                    visible: topbar.currentIndex === 2
                    anchors.fill: parent
                }
            }
        }
    }
}
