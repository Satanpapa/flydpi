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
    property bool running: false
    property string activeProfile: "Default"
    property var report: rpcClient.diagnosticReport
    property string diagnosisText: rpcClient.connected ? "Готов к диагностике" : "Оркестратор не запущен"
    property string detailText: "Запустите диагностику, чтобы получить фактический результат."

    function severityTone() {
        var severity = report["severity"] || "ok"
        if (severity === "critical") return theme.bad
        if (severity === "warning") return theme.warn
        return theme.good
    }

    function severityText() {
        var severity = report["severity"] || "ok"
        if (severity === "critical") return "КРИТИЧЕСКИ"
        if (severity === "warning") return "ВНИМАНИЕ"
        return report["schema_version"] ? "НОРМА" : "ГОТОВ"
    }

    function stages() { return report["stages"] || [] }
    function probes() { return report["probe_results"] || [] }
    function features() { return report["features"] || {} }
    function wfp() { return report["wfp_events"] || {} }

    function startDiagnostic() {
        if (running || !rpcClient.connected) return
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
            window.running = false
            window.diagnosisText = rpcClient.diagnosticReport["title"] || "Диагностика завершена"
            window.detailText = rpcClient.diagnosticReport["explanation"] || "Отчёт сформирован."
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
                    Label { text: "FlyDPI"; color: theme.text; font.pixelSize: 25; font.bold: true; Layout.leftMargin: 8; Layout.topMargin: 8 }
                    Label { text: "NETWORK DIAGNOSTICS"; color: theme.muted; font.pixelSize: 10; Layout.leftMargin: 9; Layout.bottomMargin: 12 }
                    Repeater {
                        model: ["Главная", "Диагностика", "Профили", "Настройки"]
                        delegate: Button {
                            required property string modelData
                            text: modelData
                            Layout.fillWidth: true
                            implicitHeight: 44
                            flat: true
                            horizontalAlignment: Text.AlignLeft
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
                        Label { text: rpcClient.connected ? severityText() : "OFFLINE"; color: rpcClient.connected ? severityTone() : theme.warn; font.bold: true }
                    }
                }
                StackLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true; currentIndex: window.page
                    Flickable {
                        clip: true; contentWidth: width; contentHeight: dashboard.implicitHeight + 40
                        ColumnLayout {
                            id: dashboard; anchors.left: parent.contentItem.left; anchors.right: parent.contentItem.right; anchors.top: parent.contentItem.top; anchors.margins: 28; spacing: 18
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 220; radius: theme.radius; color: theme.panel; border.color: theme.border
                                ColumnLayout { anchors.fill: parent; anchors.margins: 22; spacing: 10
                                    RowLayout { Label { text: "Результат диагностики"; color: theme.muted; font.pixelSize: 13 }; Item { Layout.fillWidth: true }; StatusPill { text: running ? "ПРОВЕРКА" : severityText(); tone: running ? theme.accent : severityTone() } }
                                    Label { text: diagnosisText; color: theme.text; font.pixelSize: 26; font.bold: true; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    Label { text: detailText; color: theme.muted; font.pixelSize: 13; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                                    RowLayout { Layout.fillWidth: true
                                        Button { text: running ? "Проверка выполняется…" : "Запустить диагностику"; enabled: !running && rpcClient.connected; Layout.preferredWidth: 230; onClicked: startDiagnostic() }
                                        Button { text: (report["recommended_action"] || ""); visible: !running && report["severity"] && report["severity"] !== "ok"; enabled: false }
                                    }
                                }
                            }
                            GridLayout {
                                columns: 3; Layout.fillWidth: true; columnSpacing: 12; rowSpacing: 12
                                Repeater {
                                    model: ["DNS", "TCP", "TLS", "RST", "Timeout", "WFP"]
                                    delegate: Rectangle {
                                        required property string modelData
                                        Layout.fillWidth: true; implicitHeight: 92; radius: 10; color: theme.panel; border.color: theme.border
                                        Column { anchors.fill: parent; anchors.margins: 16; spacing: 7
                                            Label { text: modelData; color: theme.muted; font.pixelSize: 11 }
                                            Label {
                                                text: {
                                                    var f = features()
                                                    if (modelData === "DNS") return probes().length ? "Проверено" : "—"
                                                    if (modelData === "TCP") { var ok=0; var a=probes(); for (var i=0;i<a.length;i++) if(a[i]["tcp_connected"]) ok++; return a.length ? ok+"/"+a.length : "—" }
                                                    if (modelData === "TLS") { var tls=0; var b=probes(); for (var j=0;j<b.length;j++) if(b[j]["tls_handshake"]) tls++; return b.length ? tls+"/"+b.length : "—" }
                                                    if (modelData === "RST") return f["rst_detected"] ? "Обнаружен" : "Не обнаружен"
                                                    if (modelData === "Timeout") return f["timeout_detected"] ? "Обнаружен" : "Не обнаружен"
                                                    return String(wfp()["observed"] || 0)
                                                }
                                                color: modelData === "RST" && features()["rst_detected"] ? theme.bad : modelData === "Timeout" && features()["timeout_detected"] ? theme.warn : theme.text
                                                font.pixelSize: 15; font.bold: true
                                            }
                                        }
                                    }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 260; radius: theme.radius; color: theme.panel; border.color: theme.border
                                ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 10
                                    Label { text: "Этапы проверки"; color: theme.text; font.pixelSize: 14; font.bold: true }
                                    Repeater { model: stages(); delegate: RowLayout { required property var modelData; Layout.fillWidth: true; Label { text: modelData["title"] || "Stage"; color: theme.text; Layout.fillWidth: true }; ProgressBar { from: 0; to: 100; value: modelData["progress"] || 0; Layout.preferredWidth: 150 }; StatusPill { text: modelData["status"] || "pending"; tone: (modelData["status"] || "") === "passed" ? theme.good : (modelData["status"] || "") === "failed" ? theme.bad : theme.accent } } }
                                }
                            }
                            Rectangle {
                                Layout.fillWidth: true; implicitHeight: 290; radius: theme.radius; color: theme.panel; border.color: theme.border
                                ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 10
                                    Label { text: "Проверенные цели"; color: theme.text; font.pixelSize: 14; font.bold: true }
                                    ListView { Layout.fillWidth: true; Layout.fillHeight: true; model: probes(); clip: true; delegate: RowLayout { required property var modelData; width: ListView.view.width; height: 34; Label { text: modelData["target"] || "—"; color: theme.text; Layout.fillWidth: true; elide: Text.ElideRight }; Label { text: modelData["tcp_connected"] ? "TCP ✓" : "TCP ✕"; color: modelData["tcp_connected"] ? theme.good : theme.bad; font.pixelSize: 12 }; Label { text: modelData["tls_handshake"] ? "TLS ✓" : "TLS ✕"; color: modelData["tls_handshake"] ? theme.good : theme.bad; font.pixelSize: 12 }; Label { text: modelData["error_class"] || "ok"; color: theme.muted; font.pixelSize: 11; Layout.preferredWidth: 130; elide: Text.ElideRight } } }
                                }
                            }
                        }
                    }
                    Item { ColumnLayout { anchors.fill: parent; anchors.margins: 28; Label { text: "Диагностика"; color: theme.text; font.pixelSize: 24; font.bold: true }; Label { text: "Все результаты строятся из DiagnosticReport."; color: theme.muted }; Button { text: "Запустить все тесты"; enabled: !running && rpcClient.connected; onClicked: startDiagnostic() }; Item { Layout.fillHeight: true } } }
                    Item { ColumnLayout { anchors.fill: parent; anchors.margins: 28; Label { text: "Профили ISP"; color: theme.text; font.pixelSize: 24; font.bold: true }; Label { text: activeProfile; color: theme.accent; font.pixelSize: 18; font.bold: true }; Button { text: "+ Создать профиль"; enabled: false }; Item { Layout.fillHeight: true } } }
                    Item { ColumnLayout { anchors.fill: parent; anchors.margins: 28; Label { text: "Настройки"; color: theme.text; font.pixelSize: 24; font.bold: true }; RowLayout { Label { text: "Режим"; color: theme.text; Layout.fillWidth: true }; ComboBox { model: ["Auto", "Manual"]; currentIndex: mode === "Auto" ? 0 : 1; onActivated: mode = currentText } }; Label { text: "Диагностика работает без изменения сетевого трафика."; color: theme.warn; wrapMode: Text.WordWrap; Layout.fillWidth: true }; Item { Layout.fillHeight: true } } }
                }
            }
        }
    }
}
