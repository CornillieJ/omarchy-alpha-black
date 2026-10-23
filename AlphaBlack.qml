import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui

Item {
  id: root

  property string homePath: Quickshell.env("HOME")
  property var shell: null
  property var manifest: null
  readonly property string pluginId: (manifest && manifest.id) || "jeffrey.alpha-black"
  readonly property string pluginDir: (manifest && manifest.__sourceDir) || (homePath + "/.config/omarchy/plugins/jeffrey.alpha-black")
  readonly property string script: pluginDir + "/alpha-black"
  readonly property string menuExtensionPath: homePath + "/.config/omarchy/extensions/omarchy-menu.jsonc"

  property bool opened: false
  property bool picking: false
  property bool pendingApply: false

  // The target is fixed when the editor opens (by `alpha-black` turning a
  // window on), so the editor taking focus never redirects edits to itself.
  property string address: ""
  property string windowTitle: ""
  property int r: 0
  property int g: 0
  property int b: 0
  property real tolerance: 0.1
  property real frost: 0

  readonly property string hex: "#" + [r, g, b].map(function(v) {
    return (v < 16 ? "0" : "") + v.toString(16)
  }).join("")

  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md
  property int labelWidth: Style.space(90)
  property int valueWidth: Style.space(48)

  function open(payload) {
    var args = {}
    try { args = JSON.parse(payload || "{}") || {} } catch (e) { args = {} }
    if (!args.address) return
    root.address = args.address
    root.windowTitle = args.title || ""
    root.r = args.r || 0
    root.g = args.g || 0
    root.b = args.b || 0
    root.tolerance = args.tolerance !== undefined ? args.tolerance : 0.1
    root.frost = args.frost !== undefined ? args.frost : 0
    root.picking = false
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide(root.pluginId)
  }

  function toggle() {
    if (root.opened) root.dismiss()
  }

  // Slider drags emit far faster than hyprctl round-trips; keep at most one
  // `alpha-black set` in flight and send only the latest values after it.
  function apply() {
    if (!root.address) return
    if (applyProc.running) {
      root.pendingApply = true
      return
    }
    applyProc.command = [root.script, "set", root.address,
      String(root.r), String(root.g), String(root.b), root.tolerance.toFixed(3), root.frost.toFixed(2)]
    applyProc.running = true
  }

  function setColor(hexText) {
    var m = /^#?([0-9a-fA-F]{2})([0-9a-fA-F]{2})([0-9a-fA-F]{2})/.exec(String(hexText).trim())
    if (!m) return
    root.r = parseInt(m[1], 16)
    root.g = parseInt(m[2], 16)
    root.b = parseInt(m[3], 16)
    root.apply()
  }

  function startPick() {
    root.picking = true
    pickProc.running = true
  }

  // Mirrors the shell's own comment/trailing-comma stripping (see
  // MenuModel.js) so the parse check below sees exactly what the menu itself
  // will see.
  function stripJsonc(raw) {
    return String(raw || "")
      .replace(/^\s*\/\/[^\n]*(\n|$)/gm, "")
      .replace(/,(\s*[}\]])/g, "$1")
  }

  // Adds the "trigger.alphablack" row from the README to the user's menu
  // extension file the first time this overlay loads (keepLoaded means that's
  // as soon as the plugin is enabled). No-ops if the key is already there or
  // if the file doesn't round-trip through JSON.parse before and after the
  // edit, so an enable can never corrupt an existing menu customization.
  function installMenuTrigger(raw) {
    var key = "\"trigger.alphablack\""
    if (raw.indexOf(key) !== -1) return

    var trimmed = raw.replace(/\s+$/, "")
    if (trimmed.charAt(trimmed.length - 1) !== "}") return

    var existing
    try {
      existing = JSON.parse(root.stripJsonc(raw))
    } catch (e) {
      return
    }
    var hasEntries = existing && typeof existing === "object" && Object.keys(existing).length > 0

    var scriptPath = root.script.indexOf(root.homePath + "/") === 0
      ? "$HOME" + root.script.slice(root.homePath.length)
      : root.script
    var head = trimmed.slice(0, trimmed.length - 1)
    var block =
      "  \"trigger.alphablack\": {\n" +
      "    \"icon\": \"󰈈\",\n" +
      "    \"label\": \"Alpha Black\",\n" +
      "    \"aliases\": [\"alphablack\", \"alpha black\", \"transparent black\", \"chromakey\"],\n" +
      "    \"description\": \"Toggle: make a color in the focused window transparent\",\n" +
      "    \"action\": \"" + scriptPath + "\"\n" +
      "  }\n"
    var newText = head + (hasEntries ? ",\n" : "\n") + block + "}\n"

    var after
    try {
      after = JSON.parse(root.stripJsonc(newText))
    } catch (e) {
      return
    }
    if (!after || !after["trigger.alphablack"]) return

    menuExtensionFile.setText(newText)
  }

  FileView {
    id: menuExtensionFile
    path: root.menuExtensionPath
    preload: true
    printErrors: false
    onLoaded: root.installMenuTrigger(text())
  }

  Process {
    id: applyProc
    onExited: {
      if (root.pendingApply) {
        root.pendingApply = false
        root.apply()
      }
    }
  }

  Process {
    id: pickProc
    command: ["hyprpicker", "-f", "hex"]
    stdout: StdioCollector {
      onStreamFinished: root.setColor(this.text)
    }
    onExited: {
      root.picking = false
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  component ChannelRow: Row {
    id: row
    property string label: ""
    property real value: 0
    property real minimum: 0
    property real maximum: 255
    property real step: 1
    property bool integer: true
    property int decimals: 0
    signal moved(real value)

    width: parent ? parent.width : 0
    height: slider.implicitHeight
    spacing: root.contentSpacing

    Text {
      width: root.labelWidth
      anchors.verticalCenter: parent.verticalCenter
      text: row.label
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }

    PanelSlider {
      id: slider
      width: row.width - root.labelWidth - root.valueWidth - root.contentSpacing * 2
      anchors.verticalCenter: parent.verticalCenter
      value: row.value
      minimum: row.minimum
      maximum: row.maximum
      step: row.step
      integer: row.integer
      trackColor: Style.selectedFillFor(root.foreground, Color.accent)
      fillColor: root.foreground
      knobColor: root.foreground
      onMoved: function(v) { row.moved(v) }
    }

    Text {
      width: root.valueWidth
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
      text: slider.liveValue.toFixed(row.decimals)
      color: root.foreground
      opacity: 0.7
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened && !root.picking
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-alpha-black"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    // No scrim: the point is watching the target window change underneath.
    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: Math.min(Style.space(460), panel.width - Style.gapsOut * 2)
      height: content.implicitHeight + card.contentTopInset + card.contentBottomInset
      radius: root.cornerRadius
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(80)
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_P) {
            root.startPick()
            event.accepted = true
          }
        }
      }

      Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: card.contentTopInset
        anchors.leftMargin: card.contentLeftInset
        anchors.rightMargin: card.contentRightInset
        spacing: root.contentSpacing

        Row {
          width: parent.width
          spacing: root.contentSpacing

          Rectangle {
            id: swatch
            width: Style.space(40)
            height: width
            radius: root.cornerRadius
            color: root.hex
            border.color: root.foreground
            border.width: 1
          }

          Column {
            width: parent.width - swatch.width - root.contentSpacing
            anchors.verticalCenter: parent.verticalCenter

            Text {
              width: parent.width
              text: "Alpha Black  " + root.hex
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: root.windowTitle
              color: root.foreground
              opacity: 0.6
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }
          }
        }

        ChannelRow {
          label: "Red"
          value: root.r
          onMoved: function(v) { root.r = v; root.apply() }
        }

        ChannelRow {
          label: "Green"
          value: root.g
          onMoved: function(v) { root.g = v; root.apply() }
        }

        ChannelRow {
          label: "Blue"
          value: root.b
          onMoved: function(v) { root.b = v; root.apply() }
        }

        ChannelRow {
          label: "Tolerance"
          value: root.tolerance
          minimum: 0.01
          maximum: 0.6
          step: 0.01
          integer: false
          decimals: 2
          onMoved: function(v) { root.tolerance = Math.round(v * 100) / 100; root.apply() }
        }

        ChannelRow {
          label: "Frost"
          value: root.frost
          minimum: 0
          maximum: 1
          step: 0.05
          integer: false
          decimals: 2
          onMoved: function(v) { root.frost = Math.round(v * 100) / 100; root.apply() }
        }

        Item {
          width: parent.width
          height: buttons.height

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: "Enter to close"
            color: root.foreground
            opacity: 0.5
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
          }

          Row {
            id: buttons
            anchors.right: parent.right
            spacing: root.contentSpacing

            Button {
              text: "Pick from screen"
              iconText: "󰈊"
              bordered: true
              tooltipText: "P"
              onClicked: root.startPick()
            }

            Button {
              text: "Reset"
              bordered: true
              onClicked: {
                root.r = 0
                root.g = 0
                root.b = 0
                root.tolerance = 0.1
                root.frost = 0
                root.apply()
              }
            }

            Button {
              text: "Done"
              bordered: true
              onClicked: root.dismiss()
            }
          }
        }
      }
    }
  }
}
