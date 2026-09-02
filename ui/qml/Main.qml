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

    Theme {
        id: theme
    }

    property int page: 0
    property string mode: "Auto"
    property bool running: false
    property string activeProfile: "Default"
    property var report: rpcClient.diagnosticReport
    property string diagnosisText: rpcClient.connected ? "Готов к диагностике" : "Оркестратор не запущен"
    property string detailText: "Запустите диагностику, чтобы получить фактический результат."

    function severityTone() {
        var severity = report["severity"] || "ok"
        if (severity === "critical")
            return theme.bad
        if (severity === "warning")
            return theme.warn
        return theme.good
    }

    function severityText() {
        var severity = report["severity"] || "ok"
        if (severity === "critical")
            return "КРИТИЧНО"
        if (severity === "warning")
            return "ВНИМАНИЕ"
        return report["schema_version"] ? "НОРМА" : "ГОТОВ"
    }

    function stages() {
        return report["stages"] || []
    }

    function probes() {
        return report["probe_results"] || []
    }

    function features() {
        return report["features"] || {}
    }

    function wfp() {
        return report["wfp_events"] || {}
    }

    function startDiagnostic() {
        if (running || !rpcClient.connected)
            return
        running = true
        diagnosisText = "Проводим диагностику…"
        detailText = "Проверяются DNS, TCP, TLS и корреляция WFP."
        rpcClient.probeRun([])
    }

    Connections {
        target: rpcClient

        function onConnectedChanged() {
            if (!rpcClient.connected) {
                running = false
                diagnosisText = "Оркестратор не запущен"
                detailText = "Запустите backend FlyDPI."
            } else if (!running && !rpcClient.diagnosticReport["schema_version"]) {
                diagnosisText = "Готов к диагностике"
                detailText = "Нажмите кнопку, чтобы начать проверку."
            }
        }

        function onDiagnosticReportChanged() {
            window.report = rpcClient.diagnosticReport
            running = false
            diagnosisText = rpcClient.diagnosticReport["title"] || "Диагностика завершена"
            detailText = rpcClient.diagnosticReport["explanation"] || "Отчёт сформирован."
        }

        function onErrorOccurred(message) {
            running = false
            diagnosisText = "Ошибка диагностики"
            detailText = message
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
                        model: ["Обзор", "Диагностика", "Профили", "История", "Настройки"]

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
                            }

                            onClicked: window.page = index
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

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

                            Label {
                                text: "Профиль"
                                color: theme.muted
                                font.pixelSize: 11
                            }

                            Label {
                                text: activeProfile
                                color: theme.text
                                font.pixelSize: 14
                                font.bold: true
                            }

                            Label {
                                text: mode + " режим"
                                color: theme.accent
                                font.pixelSize: 11
                            }
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
                            text: ["Обзор", "Диагностика", "Профили", "История", "Настройки"][page]
                            color: theme.text
                            font.pixelSize: 20
                            font.bold: true
                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        Label {
                            text: rpcClient.runtimeEnabled ? "WFP LIVE" : (rpcClient.connected ? "DIAGNOSTIC" : "OFFLINE")
                            color: rpcClient.runtimeEnabled ? theme.good : (rpcClient.connected ? theme.accent : theme.warn)
                            font.bold: true
                        }
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
                                implicitHeight: 220
                                radius: theme.radius
                                color: theme.panel
                                border.color: theme.border

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 22
                                    spacing: 10

                                    RowLayout {
                                        Label {
                                            text: "Результат диагностики"
                                            color: theme.muted
                                            font.pixelSize: 13
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        StatusPill {
                                            text: running ? "ПРОВЕРКА" : severityText()
                                            tone: running ? theme.accent : severityTone()
                                        }
                                    }

                                    Label {
                                        text: diagnosisText
                                        color: theme.text
                                        font.pixelSize: 26
                                        font.bold: true
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    Label {
                                        text: detailText
                                        color: theme.muted
                                        font.pixelSize: 13
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true

                                        Button {
                                            text: running ? "Проверка выполняется…" : "Запустить диагностику"
                                            enabled: !running && rpcClient.connected
                                            Layout.preferredWidth: 230
                                            onClicked: startDiagnostic()
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Button {
                                            visible: !running && report["severity"] && report["severity"] !== "ok"
                                            text: report["recommended_action"] || "Подробнее"
                                            onClicked: page = 1
                                        }
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 12

                                Repeater {
                                    model: ["DNS", "TCP", "TLS", "RST", "Timeout", "WFP"]

                                    delegate: Rectangle {
                                        required property string modelData
                                        Layout.fillWidth: true
                                        implicitHeight: 92
                                        radius: 10
                                        color: theme.panel
                                        border.color: theme.border

                                        Column {
                                            anchors.fill: parent
                                            anchors.margins: 16
                                            spacing: 7

                                            Label {
                                                text: modelData
                                                color: theme.muted
                                                font.pixelSize: 11
                                            }

                                            Label {
                                                text: modelData === "RST"
                                                      ? (features()["rst_detected"] ? "Обнаружен" : "Не обнаружен")
                                                      : modelData === "Timeout"
                                                      ? (features()["timeout_detected"] ? "Обнаружен" : "Не обнаружен")
                                                      : modelData === "WFP"
                                                      ? String(wfp()["observed"] || 0)
                                                      : modelData === "DNS"
                                                      ? (features()["poisoning_detected"] ? "Есть mismatch" : "Согласован")
                                                      : modelData === "TCP"
                                                      ? (probes().length ? probes().filter(function(x) { return x.tcp_connected }).length + "/" + probes().length : "—")
                                                      : (probes().length ? probes().filter(function(x) { return x.tls_handshake }).length + "/" + probes().length : "—")
                                                color: modelData === "RST" && features()["rst_detected"]
                                                       ? theme.bad
                                                       : modelData === "Timeout" && features()["timeout_detected"]
                                                       ? theme.warn
                                                       : theme.text
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 220
                                radius: theme.radius
                                color: theme.panel
                                border.color: theme.border

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 10

                                    RowLayout {
                                        Label {
                                            text: "Live WFP events"
                                            color: theme.text
                                            font.bold: true
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                        }

                                        Label {
                                            text: rpcClient.runtimeEnabled ? "подключено" : "нет runtime"
                                            color: rpcClient.runtimeEnabled ? theme.good : theme.muted
                                            font.pixelSize: 11
                                        }
                                    }

                                    ListView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        clip: true
                                        model: rpcClient.telemetry

                                        delegate: RowLayout {
                                            width: ListView.view.width
                                            height: 28

                                            Label {
                                                text: modelData.protocol === 6 ? "TCP" : modelData.protocol === 17 ? "UDP" : "OTHER"
                                                color: theme.accent
                                                font.pixelSize: 11
                                                Layout.preferredWidth: 55
                                            }

                                            Label {
                                                text: "port " + modelData.remote_port
                                                color: theme.text
                                                Layout.preferredWidth: 85
                                            }

                                            Label {
                                                text: "event " + modelData.kind
                                                color: theme.muted
                                                Layout.fillWidth: true
                                            }

                                            Label {
                                                text: modelData.error_code ? "error " + modelData.error_code : "ok"
                                                color: modelData.error_code ? theme.bad : theme.good
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 260
                                radius: theme.radius
                                color: theme.panel
                                border.color: theme.border

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 10

                                    Label {
                                        text: "Этапы проверки"
                                        color: theme.text
                                        font.bold: true
                                    }

                                    Repeater {
                                        model: stages()

                                        delegate: RowLayout {
                                            required property var modelData
                                            Layout.fillWidth: true

                                            Label {
                                                text: modelData["title"] || "Stage"
                                                color: theme.text
                                                Layout.fillWidth: true
                                            }

                                            ProgressBar {
                                                from: 0
                                                to: 100
                                                value: modelData["progress"] || 0
                                                Layout.preferredWidth: 150
                                            }

                                            StatusPill {
                                                text: modelData["status"] || "pending"
                                                tone: modelData["status"] === "passed"
                                                      ? theme.good
                                                      : modelData["status"] === "failed"
                                                      ? theme.bad
                                                      : theme.accent
                                            }
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 240
                                radius: theme.radius
                                color: theme.panel
                                border.color: theme.border

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 18
                                    spacing: 10

                                    Label {
                                        text: "Проверенные цели"
                                        color: theme.text
                                        font.bold: true
                                    }

                                    ListView {
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        model: probes()
                                        clip: true

                                        delegate: RowLayout {
                                            required property var modelData
                                            width: ListView.view.width
                                            height: 34

                                            Label {
                                                text: modelData["target"] || "—"
                                                color: theme.text
                                                Layout.fillWidth: true
                                            }

                                            Label {
                                                text: modelData["tcp_connected"] ? "TCP ✓" : "TCP ✕"
                                                color: modelData["tcp_connected"] ? theme.good : theme.bad
                                                font.pixelSize: 12
                                            }

                                            Label {
                                                text: modelData["tls_handshake"] ? "TLS ✓" : "TLS ✕"
                                                color: modelData["tls_handshake"] ? theme.good : theme.bad
                                                font.pixelSize: 12
                                            }

                                            Label {
                                                text: modelData["error_class"] || "ok"
                                                color: theme.muted
                                                font.pixelSize: 11
                                                Layout.preferredWidth: 130
                                                elide: Text.ElideRight
                                            }
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
                            spacing: 14

                            Label {
                                text: "Диагностика"
                                color: theme.text
                                font.pixelSize: 24
                                font.bold: true
                            }

                            Label {
                                text: report["explanation"] || "Запустите проверку сети."
                                color: theme.muted
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Button {
                                text: "Запустить полную проверку"
                                enabled: !running && rpcClient.connected
                                onClicked: startDiagnostic()
                            }

                            Item {
                                Layout.fillHeight: true
                            }
                        }
                    }

                    Item {
                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 28
                            spacing: 14

                            Label {
                                text: "Профили ISP"
                                color: theme.text
                                font.pixelSize: 24
                                font.bold: true
                            }

                            Label {
                                text: "Сохраняйте результаты для быстрого сравнения состояния сети."
                                color: theme.muted
                            }

                            RowLayout {
                                TextField {
                                    id: profileName
                                    placeholderText: "Название профиля"
                                    Layout.fillWidth: true
                                }

                                Button {
                                    text: "Сохранить"
                                    enabled: profileName.text.length > 0
                                    onClicked: rpcClient.saveProfile(
                                        profileName.text,
                                        report["recommended_action"] || "Ничего не менять",
                                        mode,
                                        1500,
                                        ["example.com", "t.me", "youtube.com"]
                                    )
                                }
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: rpcClient.profiles

                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: 58
                                    color: "transparent"
                                    border.bottom.color: theme.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10

                                        Label {
                                            text: modelData.name || "Unnamed"
                                            color: theme.text
                                            Layout.fillWidth: true
                                        }

                                        Label {
                                            text: modelData.preferred_action || "—"
                                            color: theme.muted
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
                            spacing: 14

                            Label {
                                text: "История"
                                color: theme.text
                                font.pixelSize: 24
                                font.bold: true
                            }

                            Button {
                                text: "Обновить"
                                onClicked: rpcClient.historyList()
                            }

                            ListView {
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                model: rpcClient.history

                                delegate: Rectangle {
                                    width: ListView.view.width
                                    height: 72
                                    color: "transparent"
                                    border.bottom.color: theme.border

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 10

                                        Label {
                                            text: modelData.timestamp || ""
                                            color: theme.muted
                                            Layout.preferredWidth: 200
                                        }

                                        Label {
                                            text: modelData.severity || ""
                                            color: modelData.severity === "critical"
                                                   ? theme.bad
                                                   : modelData.severity === "warning"
                                                   ? theme.warn
                                                   : theme.good
                                            Layout.preferredWidth: 90
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true

                                            Label {
                                                text: modelData.title || ""
                                                color: theme.text
                                                font.bold: true
                                            }

                                            Label {
                                                text: modelData.summary || ""
                                                color: theme.muted
                                                elide: Text.ElideRight
                                                Layout.fillWidth: true
                                            }
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
                            spacing: 18

                            Label {
                                text: "Настройки"
                                color: theme.text
                                font.pixelSize: 24
                                font.bold: true
                            }

                            RowLayout {
                                Label {
                                    text: "Режим"
                                    color: theme.text
                                    Layout.fillWidth: true
                                }

                                ComboBox {
                                    model: ["Auto", "Manual"]
                                    currentIndex: mode === "Auto" ? 0 : 1
                                    onActivated: mode = currentText
                                }
                            }

                            Label {
                                text: "Диагностика не меняет сетевой трафик автоматически."
                                color: theme.warn
                                wrapMode: Text.WordWrap
                                Layout.fillWidth: true
                            }

                            Item {
                                Layout.fillHeight: true
                            }
                        }
                    }
                }
            }
        }
    }
}
