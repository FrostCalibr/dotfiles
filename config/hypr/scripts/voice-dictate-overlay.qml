import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

PanelWindow {
    id: window

    // Matugen-generated colors — rebuilt by wallpaper.sh on every theme change
    MatugenColors { id: mc }
    
    // Show above all windows
    WlrLayershell.layer: WlrLayer.Overlay
    
    // Disable exclusive zone so Hyprland does not shift other windows
    WlrLayershell.exclusiveZone: -1
    
    // Request keyboard focus to intercept Escape
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    // Transparent background for the window
    color: "transparent"
    
    // Allow clicks to pass through
    mask: Region {}

    // Dock to left, right, and bottom to span the screen horizontally
    anchors {
        left: true
        right: true
        bottom: true
    }
    
    // Shifted down to be lower on the screen (40px)
    margins {
        bottom: 40
    }
    
    // Set implicit height for the bar area
    implicitHeight: 52

    // Expose the state property and setter function to IPC
    IpcHandler {
        target: "voice-dictate-overlay"
        
        function setState(stateName: string): void {
            currentState = stateName
        }
    }

    // State machine
    property string currentState: "recording"
    
    // Real-time audio data from CAVA
    property var cavaValues: [0, 0, 0, 0, 0, 0, 0, 0]

    // Read spectrum data from CAVA headless raw output
    Process {
        command: ["cava", "-p", "/tmp/cava-dictate.conf"]
        running: currentState === "recording"
        
        stdout: SplitParser {
            onRead: data => {
                let parts = data.split(';');
                if (parts.length >= 8) {
                    let newValues = [];
                    // Viscous exponential smoothing factor (alpha = 0.78)
                    let alpha = 0.78;
                    for (let j = 0; j < 8; j++) {
                        let newVal = parseInt(parts[j]) || 0;
                        let prevVal = cavaValues[j] || 0;
                        let smoothed = (prevVal * alpha) + (newVal * (1 - alpha));
                        newValues.push(smoothed);
                    }
                    cavaValues = newValues;
                }
            }
        }
    }

    // Cancel process to terminate dictation on Escape
    Process {
        id: cancelProcess
        command: ["/home/m_frost/.config/hypr/scripts/voice-dictate.sh", "--cancel"]
        running: false
        onRunningChanged: {
            if (!running) {
                Qt.quit()
            }
        }
    }
    
    // Phase for animations
    property real animPhase: 0
    
    // Explicitly named Timer (prevents QML garbage collection from reclaiming unnamed objects)
    Timer {
        id: globalAnimationTimer
        interval: 16 // ~60fps
        running: true
        repeat: true
        onTriggered: {
            animPhase = (animPhase + 2.2) % 360 // Balanced pacing (middle speed)
        }
    }

    // Handle state transitions
    onCurrentStateChanged: {
        if (currentState === "error") {
            shakeAnimation.start()
        }
        if (currentState === "success" || currentState === "error") {
            exitTimer.interval = currentState === "success" ? 800 : 1800
            exitTimer.start()
        }
    }

    // Snappy shake animation for failure state
    SequentialAnimation {
        id: shakeAnimation
        loops: 2
        PropertyAnimation { target: mainContainer; property: "anchors.horizontalCenterOffset"; to: -12; duration: 50; easing.type: Easing.InOutQuad }
        PropertyAnimation { target: mainContainer; property: "anchors.horizontalCenterOffset"; to: 12; duration: 100; easing.type: Easing.InOutQuad }
        PropertyAnimation { target: mainContainer; property: "anchors.horizontalCenterOffset"; to: 0; duration: 50; easing.type: Easing.InOutQuad }
    }

    // Exiting timer
    Timer {
        id: exitTimer
        running: false
        onTriggered: {
            fadeOutAnimation.start()
        }
    }

    // Fast snappy fade-out animation
    SequentialAnimation {
        id: fadeOutAnimation
        NumberAnimation { target: mainContainer; property: "opacity"; to: 0; duration: 200; easing.type: Easing.OutQuad }
        onStopped: {
            Qt.quit()
        }
    }

    Rectangle {
        id: mainContainer
        // Center the pill container horizontally inside the full-width window
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenterOffset: 0
        
        focus: true
        Keys.onPressed: (event) => {
            if (event.key === Qt.Key_Escape) {
                cancelProcess.running = true;
                event.accepted = true;
            }
        }
        
        // Snappy Apple-style layout transition (280ms)
        width: contentRow.width + 24
        height: 40
        radius: 20
        
        Behavior on width {
            NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
        }

        // Matugen background color with 90% opacity — from MatugenColors.qml
        color: Qt.rgba(mc.windowBgColor.r, mc.windowBgColor.g, mc.windowBgColor.b, 0.90)
        
        // Stateful borders — colors from Matugen palette
        border.color: {
            if (currentState === "success") return mc.tertiary
            if (currentState === "error") return mc.error
            if (currentState === "muted") return "#ffd60a"
            return Qt.rgba(mc.primary.r, mc.primary.g, mc.primary.b, 0.30)
        }
        border.width: (currentState === "success" || currentState === "error") ? 1.5 : 1

        Behavior on border.color { ColorAnimation { duration: 200 } }
        Behavior on border.width { NumberAnimation { duration: 200 } }

        Row {
            id: contentRow
            anchors.centerIn: parent
            spacing: 0
            
            // 1. Status Indicator / Icon Container
            Rectangle {
                id: iconContainer
                width: 16
                height: 16
                color: "transparent"
                anchors.verticalCenter: parent.verticalCenter
                
                // Pulsing red recording dot (breathing duration set to 1400ms for calmer pace)
                Rectangle {
                    id: redDot
                    anchors.centerIn: parent
                    width: 10
                    height: 10
                    radius: 5
                    color: Qt.rgba(mc.error.r, mc.error.g * 0.3, mc.error.b * 0.3, 1.0) // recording red: error hue darkened
                    visible: currentState === "recording"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    // Glow ring
                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width + 8
                        height: parent.height + 8
                        radius: width / 2
                        color: "transparent"
                        border.color: Qt.rgba(mc.error.r, mc.error.g * 0.3, mc.error.b * 0.3, 0.31)
                        border.width: 1.5

                        SequentialAnimation on scale {
                            loops: Animation.Infinite
                            running: currentState === "recording"
                            PropertyAnimation { to: 1.5; duration: 1400; easing.type: Easing.OutQuad }
                            PropertyAnimation { to: 1.0; duration: 1400; easing.type: Easing.OutQuad }
                        }
                        SequentialAnimation on opacity {
                            loops: Animation.Infinite
                            running: currentState === "recording"
                            PropertyAnimation { to: 0.0; duration: 1400; easing.type: Easing.OutQuad }
                            PropertyAnimation { to: 1.0; duration: 1400; easing.type: Easing.OutQuad }
                        }
                    }
                }

                // Muted microphone icon (yellow pulsing)
                Text {
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: mc.secondary
                    anchors.centerIn: parent
                    visible: currentState === "muted"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        running: currentState === "muted"
                        PropertyAnimation { to: 0.3; duration: 1000; easing.type: Easing.InOutSine }
                        PropertyAnimation { to: 1.0; duration: 1000; easing.type: Easing.InOutSine }
                    }
                }

                // Transcribing loading spinner (lavender accent)
                Text {
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: mc.primary
                    anchors.centerIn: parent
                    visible: currentState === "transcribing"
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }

                    RotationAnimation on rotation {
                        loops: Animation.Infinite
                        from: 0
                        to: 360
                        duration: 1400
                        running: currentState === "transcribing"
                    }
                }

                // Success checkmark (Matugen chartreuse #c9d77e, Apple Face ID style snappy bounce-pop)
                Text {
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: mc.tertiary
                    anchors.centerIn: parent
                    visible: currentState === "success"
                    
                    scale: visible ? 1.0 : 0.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.4
                        }
                    }
                    
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }

                // Error warning sign (Matugen error #ffb8af)
                Text {
                    text: ""
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                    color: mc.error
                    anchors.centerIn: parent
                    visible: currentState === "error"
                    
                    scale: visible ? 1.0 : 0.0
                    Behavior on scale {
                        NumberAnimation {
                            duration: 280
                            easing.type: Easing.OutBack
                            easing.overshoot: 1.4
                        }
                    }
                    
                    opacity: visible ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 120 } }
                }
            }

            // 2. Elastic Spacer (collapses to 0 width when waveRow is hidden)
            Item {
                id: waveSpacer
                width: (currentState === "recording" || currentState === "transcribing") ? 12 : 0
                height: 1
                Behavior on width {
                    NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
                }
            }

            // 3. Three sequential bouncing dots (Matugen lavender #ebb8f7, active in "transcribing" mode)
            Row {
                id: thinkingDots
                spacing: 4
                anchors.verticalCenter: parent.verticalCenter
                width: (currentState === "transcribing") ? 23 : 0 // 3 dots of 5px + 2 spacing of 4px = 23px
                visible: width > 0
                clip: true
                
                Behavior on width {
                    NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
                }

                Repeater {
                    model: 3
                    delegate: Rectangle {
                        width: 5
                        height: 5
                        radius: 2.5
                        color: mc.primary
                        anchors.verticalCenter: parent.verticalCenter
                        
                        // Explicitly bind to root's animPhase to guarantee dependency registration
                        property real localPhase: animPhase
                        
                        opacity: {
                            let rad = localPhase * Math.PI / 180;
                            let val = Math.sin(rad * 6 - index * 1.5);
                            return Math.max(0.3, 0.75 + val * 0.25);
                        }
                        scale: {
                            let rad = localPhase * Math.PI / 180;
                            let val = Math.sin(rad * 6 - index * 1.5);
                            return Math.max(0.7, 1.0 + val * 0.3);
                        }
                    }
                }
            }

            // 4. Real-time CAVA waveform with subtle idle breathing fallback (Matugen lavender #ebb8f7)
            Row {
                id: waveRow
                spacing: 3
                anchors.verticalCenter: parent.verticalCenter
                width: (currentState === "recording") ? 45 : 0 // 8 bars of 3px + 7 spacing of 3px = 45px
                visible: width > 0
                clip: true
                
                Behavior on width {
                    NumberAnimation { duration: 280; easing.type: Easing.OutQuint }
                }

                Repeater {
                    model: 8
                    delegate: Rectangle {
                        width: 3
                        radius: 1.5
                        color: mc.primary
                        anchors.verticalCenter: parent.verticalCenter
                        
                        // Explicitly bind to root's animPhase to guarantee dependency registration
                        property real localPhase: animPhase
                        
                        height: {
                            if (currentState === "recording") {
                                let rad = localPhase * Math.PI / 180;
                                let i = index;
                                
                                // 1. Idle breathing wave (prevents completely flat/dead visualizer in silence)
                                let idle = Math.sin(rad * 4 + i * 1.5) * 1.2 + 2.2;
                                
                                // 2. Real-time smoothed CAVA voice amplitude (moderated sensitivity)
                                let amplitude = cavaValues[i] || 0;
                                let voice = (amplitude / 100) * 16;
                                
                                return Math.max(4, idle + voice);
                            } else {
                                return 4;
                            }
                        }
                        
                        Behavior on height {
                            NumberAnimation { duration: 60; easing.type: Easing.OutQuad }
                        }
                    }
                }
            }
        }
    }
}
