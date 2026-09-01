import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    visible: true
    width: 980
    height: 640
    minimumWidth: 820
    minimumHeight: 560
    title: "FlyDPI"

    property string stateText: "READY"
    property string diagnosisText: "Диагностика ещё не запускалась"

    Rectangle {
        anchors.fill: parent
        color: "#101318"

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 18

            RowLayout {
                Layout.fillWidth: true
                Label {
                    text: "FlyDPI"
                    color: "white"
                    font.pixelSize: 30
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
                Label {
                    text: stateText
                    color: "#8bd17c"
                    font.pixelSize: 15
                    font.bold: true
                }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                radius: 16
                color: "#191e26"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 24
                    spacing: 10
                    Label { text: "Состояние сети"; color: "#9aa4b2"; font.pixelSize: 14 }
                    Label { text: diagnosisText; color: "white"; font.pixelSize: 23; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                    Label { text: "FlyDPI пока работает в диагностическом режиме и не модифицирует пакеты."; color: "#778191"; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                Button { text: "Запустить диагностику"; onClicked: stateText = "PROBING" }
                Button { text: "Профили"; enabled: true }
                Button { text: "Настройки"; enabled: true }
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 16
                color: "#0b0e12"
                border.color: "#252c36"

                Label {
                    anchors.fill: parent
                    anchors.margins: 20
                    text: "Журнал\n\nОжидание событий оркестратора..."
                    color: "#aab4c3"
                    font.family: "Consolas"
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
