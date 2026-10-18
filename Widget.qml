import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.Commons
import qs.Ui

// Screen Rotate bar widget. Each bar rotates the monitor it sits on: click the
// icon for a popup listing the rotations in a fixed order, with the current one
// highlighted, and pick one. All monitor work happens in bin/screen-rotate.
BarWidget {
  id: root
  moduleName: "io.github.vivek.screen-rotate"

  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("bin/screen-rotate")).replace(/^file:\/\//, ""))
  readonly property var labels: ["Normal", "Portrait, turned right", "Upside down", "Portrait, turned left"]
  // Popup order; values are Hyprland monitor transforms
  readonly property var choices: [0, 3, 1, 2]

  readonly property var barWindow: QsWindow.window
  readonly property string monitorName: barWindow && barWindow.screen ? String(barWindow.screen.name || "") : ""

  property int currentTransform: 0
  property bool saved: true
  property bool popupOpen: false
  property int cursor: 0

  function refresh() {
    if (monitorName !== "" && !getProc.running) getProc.running = true
  }

  function rotate(value) {
    popupOpen = false
    if (value === currentTransform || runProc.running) return
    run(["set", monitorName, String(value)])
  }

  function rememberRotations() {
    run(["setup"])
  }

  function run(args) {
    runProc.command = ["bash", helper].concat(args)
    runProc.running = true
  }

  function openPopup() {
    cursor = Math.max(0, choices.indexOf(currentTransform))
    popupOpen = true
    refresh()
  }

  function close() { popupOpen = false }

  visible: monitorName !== ""
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onMonitorNameChanged: refresh()
  Component.onCompleted: refresh()

  IpcHandler {
    target: "io.github.vivek.screen-rotate"

    function refresh(): void {
      root.broadcast("refresh")
    }

    // Opens on the bar of the focused monitor only
    function open(): void {
      root.broadcast("openIfFocused")
    }

    function close(): void {
      root.broadcast("close")
    }
  }

  function openIfFocused() {
    if (Hyprland.focusedMonitor && Hyprland.focusedMonitor.name === monitorName) openPopup()
  }

  // Monitor plugged in, unplugged or reconfigured elsewhere
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      var name = event && event.name ? String(event.name) : ""
      if (name === "monitoraddedv2" || name === "configreloaded") root.refresh()
    }
  }

  Process {
    id: getProc
    command: ["bash", root.helper, "get", root.monitorName]
    stdout: StdioCollector {
      onStreamFinished: {
        var parts = String(text).trim().split(/\s+/)
        var t = parseInt(parts[0])
        if (!isNaN(t)) root.currentTransform = t
        root.saved = parts[1] === "1"
      }
    }
  }

  Process {
    id: runProc
    onExited: root.broadcast("refresh")
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // nf-md-monitor (landscape) / nf-md-cellphone (portrait)
    text: String.fromCodePoint(root.currentTransform % 2 === 0 ? 0xF0379 : 0xF011C)
    tooltipText: root.popupOpen ? "" : "Rotate " + root.monitorName + ": " + (root.labels[root.currentTransform % 4] || "unknown")
    onPressed: root.popupOpen ? root.close() : root.openPopup()
  }

  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(240))
    contentHeight: popup.fittedContentHeight(column.implicitHeight)

    // Bar popups get no keyboard focus; clicking outside closes it (PopupCard)
    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      spacing: Style.space(2)

      Text {
        text: "Rotate " + root.monitorName
        color: Qt.darker(root.bar.foreground, 1.4)
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.caption
        bottomPadding: Style.space(4)
      }

      Repeater {
        model: root.choices

        Rectangle {
          id: row
          required property int modelData
          required property int index
          readonly property bool current: modelData === root.currentTransform

          width: column.width
          height: Style.space(28)
          radius: Style.cornerRadius
          color: index === root.cursor ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

          Text {
            anchors.left: parent.left
            anchors.leftMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            text: root.labels[row.modelData]
            color: row.current ? Color.accent : root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }

          // nf-md-check on the active rotation
          Text {
            anchors.right: parent.right
            anchors.rightMargin: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter
            visible: row.current
            text: String.fromCodePoint(0xF012C)
            color: Color.accent
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.body
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.cursor = row.index
            onClicked: root.rotate(row.modelData)
          }
        }
      }

      // Saving touches monitors.lua, so it only happens when the user asks
      Rectangle {
        visible: !root.saved
        width: column.width
        height: Style.space(28)
        radius: Style.cornerRadius
        color: rememberMouse.containsMouse ? Style.hoverFillFor(root.bar.foreground, Color.accent) : "transparent"

        Text {
          anchors.left: parent.left
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: "Remember after restart"
          color: Qt.darker(root.bar.foreground, 1.2)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          id: rememberMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.rememberRotations()
        }
      }
    }
  }
}
