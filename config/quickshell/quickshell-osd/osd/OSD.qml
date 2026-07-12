import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Layouts

Scope {
  id: root
  property var theme: DefaultTheme {}
  property string font: "Outfit"
  property string iconFont: "JetBrainsMono Nerd Font Propo"

  property bool showVolume: false
  property bool showBrightness: false
  property bool showMic: false
  property bool showNumLock: false
  property bool showCapsLock: false
  property bool showMedia: false

  property real volumeValue: 0
  property bool volumeMuted: false
  
  property real brightnessValue: 0
  property real maxBrightness: 1
  property bool _brightnessReady: false

  property real micValue: 0
  property bool micMuted: false

  property bool numLockOn: false
  property bool capsLockOn: false

  property string mediaTitle: ""
  property string mediaArtist: ""
  property bool mediaPlaying: false
  property var lastMediaEventPlayer: null
  // "playpause" | "next" | "prev" | "track" (MPRIS-only, e.g. Waybar click)
  property string mediaAction: "playpause"

  property bool _initialized: false

  // Initialization Timer
  Timer {
    id: initTimer
    interval: 1000
    running: true
    repeat: false
    onTriggered: root._initialized = true
  }

  // PipeWire tracking for default sink & source
  PwObjectTracker {
    objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource]
  }

  // Audio output Connections
  Connections {
    target: Pipewire.defaultAudioSink?.audio ?? null

    function onVolumeChanged() {
      root.volumeValue = Pipewire.defaultAudioSink.audio.volume;
      if (root._initialized) {
        root.showVolume = true;
        volumeHideTimer.restart();
      }
    }

    function onMutedChanged() {
      root.volumeMuted = Pipewire.defaultAudioSink.audio.muted;
      if (root._initialized) {
        root.showVolume = true;
        volumeHideTimer.restart();
      }
    }
  }

  Timer {
    id: volumeHideTimer
    interval: 1500
    onTriggered: root.showVolume = false
  }

  // Audio input (Mic) Connections
  Connections {
    target: Pipewire.defaultAudioSource?.audio ?? null

    function onVolumeChanged() {
      root.micValue = Pipewire.defaultAudioSource.audio.volume;
      if (root._initialized) {
        root.showMic = true;
        micHideTimer.restart();
      }
    }

    function onMutedChanged() {
      root.micMuted = Pipewire.defaultAudioSource.audio.muted;
      if (root._initialized) {
        root.showMic = true;
        micHideTimer.restart();
      }
    }
  }

  Timer {
    id: micHideTimer
    interval: 1500
    onTriggered: root.showMic = false
  }

  // Brightness monitoring
  FileView {
    id: brightnessFile
    path: ""
    watchChanges: true
    onFileChanged: brightnessReadProc.running = true
  }

  Process {
    id: brightnessReadProc
    command: ["brightnessctl", "get"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const val = parseInt(text.trim());
        if (!isNaN(val) && root.maxBrightness > 0) {
          root.brightnessValue = val / root.maxBrightness;
          if (root._brightnessReady && root._initialized) {
            root.showBrightness = true;
            brightnessHideTimer.restart();
          }
          root._brightnessReady = true;
        }
      }
    }
  }

  Process {
    id: backlightDiscovery
    command: ["sh", "-c", "p=$(ls -d /sys/class/backlight/*/brightness 2>/dev/null | head -1); [ -n \"$p\" ] && echo \"$p\" && cat \"${p%brightness}max_brightness\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        if (lines.length >= 2) {
          const max = parseInt(lines[1]);
          if (!isNaN(max) && max > 0) root.maxBrightness = max;
          brightnessFile.path = lines[0];
          brightnessReadProc.running = true;
        }
      }
    }
  }

  Timer {
    id: brightnessHideTimer
    interval: 1500
    onTriggered: root.showBrightness = false
  }

  // Modifier Lock Keys Watcher (Num Lock and Caps Lock)
  Process {
    id: modifierWatcher
    command: ["python", "-u", Quickshell.env("HOME") + "/.config/quickshell/quickshell-osd/osd/modifier_watcher.py"]
    running: true
    stdout: SplitParser {
      onRead: (data) => {
        var parts = data.trim().split(" ");
        if (parts.length === 3) {
          var action = parts[0];
          var numOn = parts[1] === "1";
          var capsOn = parts[2] === "1";
          
          if (action === "CHANGE" && root._initialized) {
            if (numOn !== root.numLockOn) {
              root.numLockOn = numOn;
              root.showNumLock = true;
              numLockHideTimer.restart();
            }
            if (capsOn !== root.capsLockOn) {
              root.capsLockOn = capsOn;
              root.showCapsLock = true;
              capsLockHideTimer.restart();
            }
          } else if (action === "INIT") {
            root.numLockOn = numOn;
            root.capsLockOn = capsOn;
          }
        }
      }
    }
  }

  Timer {
    id: numLockHideTimer
    interval: 1500
    onTriggered: root.showNumLock = false
  }

  Timer {
    id: capsLockHideTimer
    interval: 1500
    onTriggered: root.showCapsLock = false
  }

  // FileView watches /tmp/qs-media-action written by Hyprland keybinds.
  // This is the PRIMARY trigger for physical keys — it fires even when the
  // track title doesn't change (e.g. Spotify's restart-current-track on prev).
  FileView {
    id: mediaActionFile
    path: "/tmp/qs-media-action"
    watchChanges: true
    onFileChanged: reload()
    onTextChanged: {
      if (!root._initialized) return;
      const action = mediaActionFile.text().trim();
      if (action === "next" || action === "prev" || action === "playpause") {
        root.mediaAction = action;
        root.showMedia = true;
        mediaHideTimer.restart();
      }
    }
  }

  // Reactive multi-player MPRIS connection pool.
  // These handlers keep title/artist/playing state fresh for ALL triggers
  // (physical keys AND software triggers like Waybar click).
  Instantiator {
    model: Mpris.players
    delegate: Connections {
      target: modelData
      ignoreUnknownSignals: true

      function onTrackTitleChanged() {
        if (!root._initialized || !modelData.trackTitle) return;
        root.lastMediaEventPlayer = modelData;
        root.mediaTitle  = modelData.trackTitle  || "";
        root.mediaArtist = modelData.trackArtist || "";
        root.mediaPlaying = modelData.isPlaying;
        // Only show OSD here for software-triggered events (Waybar etc.).
        // Physical key presses are already handled by the FileView above.
        if (!root.showMedia) {
          root.mediaAction = "track";
          root.showMedia = true;
          mediaHideTimer.restart();
        }
      }

      function onIsPlayingChanged() {
        if (!root._initialized) return;
        root.lastMediaEventPlayer = modelData;
        root.mediaTitle  = modelData.trackTitle  || "";
        root.mediaArtist = modelData.trackArtist || "";
        root.mediaPlaying = modelData.isPlaying;
        if (!root.showMedia) {
          root.mediaAction = "playpause";
          root.showMedia = true;
          mediaHideTimer.restart();
        }
      }
    }
  }

  Timer {
    id: mediaHideTimer
    interval: 2200
    onTriggered: root.showMedia = false
  }

  Variants {
    model: Quickshell.screens

    PanelWindow {
      required property var modelData
      screen: modelData

      visible: root.showVolume || root.showBrightness || root.showMic || root.showNumLock || root.showCapsLock || root.showMedia
      focusable: false
      color: "transparent"

      WlrLayershell.layer: WlrLayer.Overlay
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
      WlrLayershell.namespace: "quickshell-osd"

      exclusionMode: ExclusionMode.Ignore
      mask: Region {}

      anchors {
        right: true
        top: true
        bottom: true
      }

      implicitWidth: root.showMedia ? 260 : 70

      Column {
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 12

        // Volume pill — vertical
        Rectangle {
          id: volumePill
          width: 36
          height: 200
          radius: 25
          color: root.theme.bgBase
          border.color: root.theme.bgBorder
          border.width: 1
          opacity: root.showVolume ? 1 : 0
          visible: opacity > 0

          Behavior on opacity { NumberAnimation { duration: 150 } }

          Accessible.role: Accessible.ProgressBar
          Accessible.name: root.volumeMuted ? "Volume: muted" : "Volume: " + Math.round(root.volumeValue * 100) + "%"

          ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            spacing: 8

            Text {
              text: root.volumeMuted ? "Mute" : Math.round(root.volumeValue * 100) + "%"
              color: root.theme.textSecondary
              font.pixelSize: 10
              font.family: root.font
              Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
              Layout.fillHeight: true
              Layout.alignment: Qt.AlignHCenter
              width: 8
              radius: 4
              color: root.theme.bgSurface
              border.color: root.theme.bgBorder
              border.width: 1
              clip: true

              Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 2
                height: Math.max(0, (parent.height - 4) * Math.max(0, Math.min(1, root.volumeMuted ? 0 : root.volumeValue)))
                radius: 3
                color: root.volumeMuted ? root.theme.textMuted : root.theme.accentPrimary

                Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
              }
            }

            Text {
              text: {
                if (root.volumeMuted || root.volumeValue <= 0) return "󰖁";
                if (root.volumeValue < 0.33) return "󰕿";
                if (root.volumeValue < 0.66) return "󰖀";
                return "󰕾";
              }
              color: root.volumeMuted ? root.theme.textMuted : root.theme.accentPrimary
              font.pixelSize: 15
              font.family: root.iconFont
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }

        // Brightness pill — vertical
        Rectangle {
          id: brightnessPill
          width: 36
          height: 200
          radius: 25
          color: root.theme.bgBase
          border.color: root.theme.bgBorder
          border.width: 1
          opacity: root.showBrightness ? 1 : 0
          visible: opacity > 0

          Behavior on opacity { NumberAnimation { duration: 150 } }

          Accessible.role: Accessible.ProgressBar
          Accessible.name: "Brightness: " + Math.round(root.brightnessValue * 100) + "%"

          ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            spacing: 8

            Text {
              text: Math.round(root.brightnessValue * 100) + "%"
              color: root.theme.textSecondary
              font.pixelSize: 10
              font.family: root.font
              Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
              Layout.fillHeight: true
              Layout.alignment: Qt.AlignHCenter
              width: 8
              radius: 4
              color: root.theme.bgSurface
              border.color: root.theme.bgBorder
              border.width: 1
              clip: true

              Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 2
                height: Math.max(0, (parent.height - 4) * Math.max(0, Math.min(1, root.brightnessValue)))
                radius: 3
                color: root.theme.accentOrange

                Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
              }
            }

            Text {
              text: "󰃠"
              color: root.theme.accentOrange
              font.pixelSize: 15
              font.family: root.iconFont
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }

        // Microphone Pill — vertical
        Rectangle {
          id: micPill
          width: 36
          height: 200
          radius: 25
          color: root.theme.bgBase
          border.color: root.theme.bgBorder
          border.width: 1
          opacity: root.showMic ? 1 : 0
          visible: opacity > 0

          Behavior on opacity { NumberAnimation { duration: 150 } }

          Accessible.role: Accessible.ProgressBar
          Accessible.name: root.micMuted ? "Mic: muted" : "Mic: " + Math.round(root.micValue * 100) + "%"

          ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 12
            anchors.bottomMargin: 12
            anchors.leftMargin: 0
            anchors.rightMargin: 0
            spacing: 8

            Text {
              text: root.micMuted ? "Mute" : Math.round(root.micValue * 100) + "%"
              color: root.theme.textSecondary
              font.pixelSize: 10
              font.family: root.font
              Layout.alignment: Qt.AlignHCenter
            }

            Rectangle {
              Layout.fillHeight: true
              Layout.alignment: Qt.AlignHCenter
              width: 8
              radius: 4
              color: root.theme.bgSurface
              border.color: root.theme.bgBorder
              border.width: 1
              clip: true

              Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 2
                height: Math.max(0, (parent.height - 4) * Math.max(0, Math.min(1, root.micMuted ? 0 : root.micValue)))
                radius: 3
                color: root.micMuted ? root.theme.textMuted : root.theme.accentCyan

                Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
              }
            }

            Text {
              text: root.micMuted ? "󰍭" : "󰍬"
              color: root.micMuted ? root.theme.textMuted : root.theme.accentCyan
              font.pixelSize: 15
              font.family: root.iconFont
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }

        // Num Lock Pill — compact vertical
        Rectangle {
          id: numLockPill
          width: 36
          height: 80
          radius: 18
          color: root.theme.bgBase
          border.color: root.theme.bgBorder
          border.width: 1
          opacity: root.showNumLock ? 1 : 0
          visible: opacity > 0

          Behavior on opacity { NumberAnimation { duration: 150 } }

          ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 6

            Text {
              text: "Num"
              color: root.theme.textSecondary
              font.pixelSize: 9
              font.family: root.font
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: root.numLockOn ? "On" : "Off"
              color: root.numLockOn ? root.theme.accentGreen : root.theme.textMuted
              font.pixelSize: 10
              font.bold: true
              font.family: root.font
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: "󰎦"
              color: root.numLockOn ? root.theme.accentGreen : root.theme.textMuted
              font.pixelSize: 16
              font.family: root.iconFont
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }

        // Caps Lock Pill — compact vertical
        Rectangle {
          id: capsLockPill
          width: 36
          height: 80
          radius: 18
          color: root.theme.bgBase
          border.color: root.theme.bgBorder
          border.width: 1
          opacity: root.showCapsLock ? 1 : 0
          visible: opacity > 0

          Behavior on opacity { NumberAnimation { duration: 150 } }

          ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            spacing: 6

            Text {
              text: "Caps"
              color: root.theme.textSecondary
              font.pixelSize: 9
              font.family: root.font
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: root.capsLockOn ? "On" : "Off"
              color: root.capsLockOn ? root.theme.accentGreen : root.theme.textMuted
              font.pixelSize: 10
              font.bold: true
              font.family: root.font
              Layout.alignment: Qt.AlignHCenter
            }

            Text {
              text: "󰬛"
              color: root.capsLockOn ? root.theme.accentGreen : root.theme.textMuted
              font.pixelSize: 16
              font.family: root.iconFont
              Layout.alignment: Qt.AlignHCenter
            }
          }
        }

        // Media Notification Pill — dynamic width horizontal card
        Rectangle {
          id: mediaPill
          width: 240
          height: 70
          radius: 16
          color: root.theme.bgBase
          border.color: root.theme.bgBorder
          border.width: 1
          opacity: root.showMedia ? 1 : 0
          visible: opacity > 0

          Behavior on opacity { NumberAnimation { duration: 150 } }

          RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 12

            Text {
              text: {
                if (root.mediaAction === "next") return "󰒭";  // skip-next
                if (root.mediaAction === "prev") return "󰒮";  // skip-prev
                return root.mediaPlaying ? "󰐊" : "󰏤";        // play / pause
              }
              color: root.theme.accentPrimary
              font.pixelSize: 24
              font.family: root.iconFont
              Layout.alignment: Qt.AlignVCenter
            }

            ColumnLayout {
              Layout.fillWidth: true
              Layout.alignment: Qt.AlignVCenter
              spacing: 2

              Text {
                text: root.mediaTitle || "Unknown Title"
                color: root.theme.textPrimary
                font.pixelSize: 12
                font.bold: true
                font.family: root.font
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              Text {
                text: root.mediaArtist || "Unknown Artist"
                color: root.theme.textSecondary
                font.pixelSize: 10
                font.family: root.font
                elide: Text.ElideRight
                Layout.fillWidth: true
              }
            }
          }
        }
      }
    }
  }
}
