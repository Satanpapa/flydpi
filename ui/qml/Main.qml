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
    property string stateText: "ГОТОВ"
    property color stateTone: theme.good
    property string diagnosisText: "Сеть работает нормально"
    property string detailText: "Запустите диагностику, чтобы проверить DNS, TCP и TLS."
    property real progressValue: 0
    property bool running: false
    property string activeProfile: "Default"
    property var logs: [
        "[INFO] WFP observer: ready",
        "[INFO] Probe engine: ready",
        "[INFO] Active profile: Default",
        "[INFO] No active traffic policy"
    ]

    function addLog(message) {
        var next = logs.slice()
        next.push(message)
        if (next.length > 80) next.shift()
        logs = next
    }

    function setBusy(busy) {
        running = busy
        if (busy) {
            stateText = "ДИАГНОСТИКА"
            stateTone = theme.accent
            progressValue = 0.08
            addLog("[INFO] Probe sequence started")
        }
    }

    Rectangle {
        anchors.fill: parent
        color: theme.bg

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 220
                color: "#0a0d12"

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10

                    Label {
                        text: "FlyDPI"
                        color: theme.text
                        font.pixelSize: 25
                        font.bold: true
                        Layout.leftMargin: 8
                        Layout.topMargin: 8
                    }
                    Label {
                        text: "NETWORK DIAGNOSTICS"
                        color: theme.muted
                        font.pixelSize: 10
                        Layout.leftMargin: 9
                        Layout.bottomMargin: 12
                    }

                    Repeater {
                        model: ["Главная", "Диагностика", "Профили", "Настройки"]
                        delegate: Button {
                            required property string modelData
                            text: modelData
                            Layout.fillWidth: true
                            implicitHeight: 44
                            flat: true
                            horizontalAlignment: Text.AlignLeft
                            contentItem: Label {
                                text: parent.text
                                color: index === window.page ? theme.text : theme.muted
                                font.pixelSize: 14
                                font.bold: index === window.page
                                leftPadding: 12
                            }
                            background: Rectangle {
                                radius: 8
                                color: index === window.page ? theme.panelAlt : "transparent"
                                border.color: index === window.page ? theme.border : "transparent"
                            }
                            onClicked: window.page = index
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 86
                        radius: 10
                        color: theme.panel
                        border.color: theme.border
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 5
                            Label { text: "Профиль"; color: theme.muted; font.pixelSize: 11 }
                            Label { text: activeProfile; color: theme.text; font.pixelSize: 14; font.bold: true }
                            Label { text: mode + " режим"; color: theme.accent; font.pixelSize: 11 }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 68
                    color: theme.bg
                    border.bottom.color: theme.border

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 20
                        Label {
                            text: page === 0 ? "Обзор" : page === 1 ? "Диагностика" : page === 2 ? "Профили" : "Настройки"
                            color: theme.text
                            font.pixelSize: 20
                            font.bold: true
                        }
                        Item { Layout.fillWidth: true }
                        StatusPill { text: stateText; tone: stateTone }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: window.page

                    Flickable {
                        clip: true
                        contentWidth: width
                        contentHeight: dashboard.implicitHeight + 40
                        ColumnLayout {
                            id: dashboard
                            anchors.left: parent.contentItem.left
                            anchors.right: parent.contentItem.right
                            anchors.top: parent.contentItem.top
                            anchors.margins: 28
                            spacing: 18

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 180
                                radius: theme.radius
                                color: theme.panel
                                border.color: theme.border
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 22
                                    spacing: 9
                                    RowLayout {
                                        Label { text: "Состояние сети"; color: theme.muted; font.pixelSize: 13 }
                                        Item { Layout.fillWidth: true }
                                        StatusPill { text: stateText; tone: stateTone }
                                    }
                                    Label { text: diagnosisText; color: theme.text; font.pixelSize: 25; font.bold: true }
                                    Label { text: detailText; color: theme.muted; font.pixelSize: 13; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                                    ProgressBar { Layout.fillWidth: true; visible: running; value: progressValue }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12
                                Button {
                                    text: running ? "Диагностика..." : "Запустить диагностику"
                                    enabled: !running
                                    Layout.preferredWidth: 210
                                    onClicked: window.setBusy(true)
                                }
                                Button { text: "Профили"; onClicked: window.page = 2 }
                                Button { text: "Настройки"; onClicked: window.page = 3 }
                            }

                            GridLayout {
                                columns: 3
                                Layout.fillWidth: true
                                columnSpacing: 12
                                rowSpacing: 12
                                Repeater {
                                    model: [
                                        ["DNS", "Готов", theme.good],
                                        ["TCP", "Готов", theme.good],
                                        ["TLS", "Готов", theme.good],
                                        ["RST", "Не обнаружен", theme.good],
                                        ["Timeout", "Не обнаружен", theme.good],
                                        ["Profile", activeProfile, theme.accent]
                                    ]
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 100
                                        radius: 10
                                        color: theme.panel
                                        border.color: theme.border
                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 7
                                            Label { text: modelData[0]; color: theme.muted; font.pixelSize: 11 }
                                            Label { text: modelData[1]; color: modelData[2]; font.pixelSize: 15; font.bold: true; elide: Text.ElideRight }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 190
                                radius: theme.radius
                                color: theme.panel
                                border.color: theme.border
                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 8
                                    RowLayout {
                                        Label { text: "Последние события"; color: theme.text; font.pixelSize: 14; font.bold: true }
                                        Item { Layout.fillWidth: true }
                                        Button { text: "Очистить"; flat: true; onClicked: logs = [] }
                                    }
                                    ListView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        model: logs
                                        clip: true
                                        delegate: Label {
                                            width: ListView.view.width
                                            text: modelData
                                            color: theme.muted
                                            font.family: "Consolas"
                                            font.pixelSize: 12
                                            elide: Text.ElideRight
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 28
                            spacing: 16
                            Label { text: "Полная проверка"; color: theme.text; font.pixelSize: 24; font.bold: true }
                            Label { text: "DNS → TCP → TLS → WFP telemetry. Никаких скрытых изменений настроек системы."; color: theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            Repeater {
                                model: ["DNS consistency", "TCP connect", "TLS handshake", "WFP telemetry correlation"]
                                delegate: Rectangle {
                                    required property string modelData
                                    Layout.fillWidth: true
                                    implicitHeight: 66
                                    radius: 10
                                    color: theme.panel
                                    border.color: theme.border
                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 16
                                        Label { text: modelData; color: theme.text; Layout.fillWidth: true }
                                        StatusPill { text: "ГОТОВ"; tone: theme.good }
                                    }
                                }
                            }
                            Item { Layout.fillHeight: true }
                            Button { text: "Запустить все тесты"; enabled: !running; onClicked: window.setBusy(true) }
                        }
                    }

                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 28
                            spacing: 16
                            Label { text: "Профили ISP"; color: theme.text; font.pixelSize: 24; font.bold: true }
                            Label { text: "Профиль хранит результаты диагностики и настройки политики. Он не содержит паролей или ключей."; color: theme.muted; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 105
                                radius: 10
                                color: theme.panel
                                border.color: theme.accent
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    ColumnLayout { Layout.fillWidth: true; Label { text: activeProfile; color: theme.text; font.pixelSize: 16; font.bold: true } Label { text: "Активный профиль"; color: theme.muted } }
                                    Button { text: "Активировать" }
                                }
                            }
                            Button { text: "+ Создать профиль" }
                            Item { Layout.fillHeight: true }
                        }
                    }

                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 28
                            spacing: 18
                            Label { text: "Настройки"; color: theme.text; font.pixelSize: 24; font.bold: true }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Режим работы"; color: theme.text; Layout.fillWidth: true }
                                ComboBox { model: ["Auto", "Manual"]; currentIndex: mode === "Auto" ? 0 : 1; onActivated: mode = currentText }
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                Label { text: "Диагностический таймаут"; color: theme.text; Layout.fillWidth: true }
                                SpinBox { from: 500; to: 5000; stepSize: 100; value: 1500 }
                                Label { text: "мс"; color: theme.muted }
                            }
                            RowLayout { Layout.fillWidth: true; CheckBox { checked: true } Label { text: "Показывать подробный журнал"; color: theme.text } }
                            Item { Layout.fillHeight: true }
                            Label { text: "Diagnostic-only: программа не изменяет сетевой трафик на этом этапе."; color: theme.warn; wrapMode: Text.WordWrap; Layout.fillWidth: true }
                        }
                    }
                }
            }
        }
    }

    Timer {
        interval: 350
        running: running
        repeat: true
        onTriggered: {
            progressValue = Math.min(1.0, progressValue + 0.12)
            if (progressValue >= 1.0) {
                running = false
                stateText = "ГОТОВ"
                stateTone = theme.good
                diagnosisText = "Блокировок не обнаружено"
                detailText = "Базовая диагностика завершена успешно."
                addLog("[INFO] Probe sequence completed")
            }
        }
    }
}
