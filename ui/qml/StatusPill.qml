import QtQuick
import QtQuick.Controls

Rectangle {
    id: root
    property string text: "ГОТОВ"
    property color tone: "#3fb950"
    implicitWidth: label.implicitWidth + 24
    implicitHeight: 30
    radius: 15
    color: Qt.alpha(tone, 0.14)
    border.color: Qt.alpha(tone, 0.35)

    Label {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.tone
        font.pixelSize: 12
        font.bold: true
    }
}
