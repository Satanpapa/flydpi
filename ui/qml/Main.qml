import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: window
    visible: true
    width: 1180
    height: 760
    minimumWidth: 980
    minimumHeight: 650
    title: "FlyDPI"

    Theme { id: theme }
    property int page: 0
    property string mode: "Auto"
    property string stateText: rpcClient.connected ? "ГОТОВ" : "OFFLINE"
    property color stateTone: rpcClient.connected ? theme.good : theme.warn
    property string diagnosisText: rpcClient.connected ? "Готов к диагностике" : "Оркестратор не запущен"
    property string detailText: "Никаких изменений сетевого трафика без явного действия пользователя."
    property real progressValue: 0
    property bool running: false
    property string activeProfile: "Default"
    property var logs: ["[INFO] GUI started"]

    function addLog(message) {
        var next = logs.slice(); next.push(message)
        if (next.length > 80) next.shift()
        logs = next
    }

    function startProbe() {
        if (!rpcClient.connected || running) return
        running = true; progressValue = 0.05
        stateText = "ДИАГНОСТИКА"; stateTone = theme.accent
        diagnosisText = "Проверяем сеть…"; addLog("[INFO] Requesting probe.run")
        rpcClient.probeRun(["example.com", "t.me", "youtube.com"])
    }

    Connections {
        target: rpcClient
        function onConnectedChanged() {
            if (rpcClient.connected) { stateText = "ГОТОВ"; stateTone = theme.good; addLog("[INFO] Orchestrator connected") }
            else { stateText = "OFFLINE"; stateTone = theme.warn; addLog("[WARN] Orchestrator disconnected") }
        }
        function onErrorOccurred(message) {
            running = false; progressValue = 0; stateText = "ОШИБКА"; stateTone = theme.bad
            diagnosisText = "Не удалось выполнить диагностику"; detailText = message; addLog("[ERROR] " + message)
        }
        function onResultReceived(id, json) {
            if (!running) return
            running = false; progressValue = 1
            stateText = "ГОТОВ"; stateTone = theme.good
            diagnosisText = "Диагностика завершена"
            detailText = "Ответ orchestrator получен. Результаты доступны в журнале."
            addLog("[INFO] probe.run completed id=" + id)
            addLog("[DATA] " + json)
        }
    }

    Rectangle {
        anchors.fill: parent; color: theme.bg
        RowLayout {
            anchors.fill: parent; spacing: 0
            Rectangle {
                Layout.fillHeight: true; Layout.preferredWidth: 220; color: "#0a0d12"
                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 16; spacing: 10
                    Label { text: "FlyDPI"; color: theme.text; font.pixelSize: 25; font.bold: true; Layout.leftMargin: 8; Layout.topMargin: 8 }
                    Label { text: "NETWORK DIAGNOSTICS"; color: theme.muted; font.pixelSize: 10; Layout.leftMargin: 9; Layout.bottomMargin: 12 }
                    Repeater {
                        model: ["Главная", "Диагностика", "Профили", "Настройки"]
                        delegate: Button {
                            required property string modelData
                            text: modelData; Layout.fillWidth: true; implicitHeight: 44; flat: true; horizontalAlignment: Text.AlignLeft
                            contentItem: Label { text: parent.text; color: index === window.page ? theme.text : theme.muted; font.pixelSize: 14; font.bold: index === window.page; leftPadding: 12 }
                            background: Rectangle { radius: 8; color: index === window.page ? theme.panelAlt : "transparent"; border.color: index === window.page ? theme.border : "transparent" }
                            onClicked: window.page = index
                        }
                    }
                    Item { Layout.fillHeight: true }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 86; radius: 10; color: theme.panel; border.color: theme.border
                        Column { anchors.fill: parent; anchors.margins: 12; spacing: 5
                            Label { text: "Профиль"; color: theme.muted; font.pixelSize: 11 }
                            Label { text: activeProfile; color: theme.text; font.pixelSize: 14; font.bold: true }
                            Label { text: mode + " режим"; color: theme.accent; font.pixelSize: 11 }
                        }
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
                Rectangle {
                    Layout.fillWidth: true; implicitHeight: 68; color: theme.bg; border.bottom.color: theme.border
                    RowLayout { anchors.fill: parent; anchors.margins: 20
                        Label { text: page === 0 ? "Обзор" : page === 1 ? "Диагностика" : page === 2 ? "Профили" : "Настройки"; color: theme.text; font.pixelSize: 20; font.bold: true }
                        Item { Layout.fillWidth: true }
                        Label { text: stateText; color: stateTone; font.bold: true }
                    }
                }
                StackLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; currentIndex: window.page
                    Item {
                        ColumnLayout { anchors.fill: parent; anchors.margins: 28; spacing: 18
                            Rectangle { Layout.fillWidth: true; implicitHeight: 180; radius: theme.radius; color: theme.panel; border.color: theme.border
                                ColumnLayout { anchors.fill: parent; anchors.margins: 22; spacing: 10
                                    Label { text: "Состояние сети"; color: theme.muted }
                                    Label { text: diagnosisText; color: theme.text; font.pixelSize: 25; font.bold: true }
                                    Label { text: detailText; color: theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                    ProgressBar { visible: running; Layout.fillWidth: true; value: progressValue }
                                }
                            }
                            RowLayout { Layout.fillWidth: true
                                Button { text: running ? "Диагностика…" : "Запустить диагностику"; enabled: !running && rpcClient.connected; onClicked: startProbe() }
                                Button { text: "Профили"; onClicked: page = 2 }
                                Button { text: "Настройки"; onClicked: page = 3 }
                            }
                            GridLayout { columns: 3; Layout.fillWidth: true; columnSpacing: 12; rowSpacing: 12
                                Repeater { model: [["RPC", rpcClient.connected ? "Подключён" : "Офлайн"], ["DNS", "Ожидает"], ["TCP", "Ожидает"], ["TLS", "Ожидает"], ["RST", "Ожидает"], ["Профиль", activeProfile]]
                                    delegate: Rectangle { required property var modelData; Layout.fillWidth: true; implicitHeight: 92; radius: 10; color: theme.panel; border.color: theme.border
                                        Column { anchors.fill: parent; anchors.margins: 15; spacing: 6; Label { text: modelData[0]; color: theme.muted; font.pixelSize: 11 }; Label { text: modelData[1]; color: theme.text; font.bold: true; elide: Text.ElideRight } }
                                    }
                                }
                            }
                            Rectangle { Layout.fillWidth: true; Layout.fillHeight: true; radius: theme.radius; color: theme.panel; border.color: theme.border
                                ColumnLayout { anchors.fill: parent; anchors.margins: 18
                                    RowLayout { Layout.fillWidth: true; Label { text: "Журнал"; color: theme.text; font.bold: true }; Item { Layout.fillWidth: true }; Button { text: "Очистить"; flat: true; onClicked: logs = [] } }
                                    ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: logs; clip: true; delegate: Label { width: ListView.view.width; text: modelData; color: theme.muted; font.family: "Consolas"; font.pixelSize: 12; wrapMode: Text.Wrap } }
                                }
                            }
                        }
                    }
                    Item { ColumnLayout { anchors.fill: parent; anchors.margins: 28; Label { text: "Диагностика"; color: theme.text; font.pixelSize: 24; font.bold: true }; Label { text: "Результат строится только по наблюдаемым сетевым событиям."; color: theme.muted }; Button { text: "Запустить все тесты"; enabled: !running && rpcClient.connected; onClicked: startProbe() }; Item { Layout.fillHeight: true } } }
                    Item { ColumnLayout { anchors.fill: parent; anchors.margins: 28; Label { text: "Профили ISP"; color: theme.text; font.pixelSize: 24; font.bold: true }; Label { text: activeProfile; color: theme.accent; font.pixelSize: 18; font.bold: true }; Button { text: "+ Создать профиль" }; Item { Layout.fillHeight: true } } }
                    Item { ColumnLayout { anchors.fill: parent; anchors.margins: 28; Label { text: "Настройки"; color: theme.text; font.pixelSize: 24; font.bold: true }; RowLayout { Label { text: "Режим"; color: theme.text; Layout.fillWidth: true }; ComboBox { model: ["Auto", "Manual"]; currentIndex: mode === "Auto" ? 0 : 1; onActivated: mode = currentText } }; RowLayout { Label { text: "Таймаут"; color: theme.text; Layout.fillWidth: true }; SpinBox { from: 500; to: 5000; stepSize: 100; value: 1500 }; Label { text: "мс"; color: theme.muted } }; Label { text: "Низкоуровневая политика пока не активируется из GUI."; color: theme.warn; wrapMode: Text.WordWrap; Layout.fillWidth: true }; Item { Layout.fillHeight: true } } }
                }
            }
        }
    }
}
