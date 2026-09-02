#include "RpcClient.h"

#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonValue>

RpcClient::RpcClient(QObject* parent) : QObject(parent) {
    connect(&m_socket, &QTcpSocket::connected, this, &RpcClient::onConnected);
    connect(&m_socket, &QTcpSocket::readyRead, this, &RpcClient::onReadyRead);
    connect(&m_socket, &QTcpSocket::errorOccurred, this, &RpcClient::onSocketError);
    m_telemetryTimer.setInterval(500);
    connect(&m_telemetryTimer, &QTimer::timeout, this, &RpcClient::pollTelemetry);
}

bool RpcClient::connected() const { return m_socket.state() == QAbstractSocket::ConnectedState; }
QVariantMap RpcClient::diagnosticReport() const { return m_diagnosticReport; }
QVariantList RpcClient::history() const { return m_history; }
QVariantList RpcClient::profiles() const { return m_profiles; }
QVariantList RpcClient::telemetry() const { return m_telemetry; }
bool RpcClient::runtimeEnabled() const { return m_runtimeEnabled; }

void RpcClient::connectToOrchestrator() { if (!connected()) m_socket.connectToHost(QStringLiteral("127.0.0.1"), 27654); }
void RpcClient::onConnected() { emit connectedChanged(); statusGet(); historyList(); profileList(); m_telemetryTimer.start(); }

void RpcClient::send(const QString& method, const QJsonObject& params) {
    if (!connected()) { emit errorOccurred(QStringLiteral("Оркестратор недоступен")); return; }
    const quint64 id = m_nextId++;
    QJsonObject request{{"jsonrpc","2.0"},{"id",static_cast<qint64>(id)},{"method",method},{"params",params}};
    m_socket.write(QJsonDocument(request).toJson(QJsonDocument::Compact) + '\n');
}

void RpcClient::statusGet() { send(QStringLiteral("status.get"), {}); }
void RpcClient::probeRun(const QStringList& targets) {
    QJsonArray array; for (const auto& target : targets) array.append(target);
    QJsonObject params; if (!targets.isEmpty()) params.insert(QStringLiteral("targets"), array);
    send(QStringLiteral("diagnostic.run"), params);
}
void RpcClient::historyList() { send(QStringLiteral("history.list"), {}); }
void RpcClient::profileList() { send(QStringLiteral("profile.list"), {}); }
void RpcClient::saveProfile(const QString& name, const QString& action, const QString& mode, int timeoutMs, const QStringList& targets) {
    QJsonArray arr; for (const auto& t : targets) arr.append(t);
    send(QStringLiteral("profile.save"), {{"name",name},{"preferred_action",action},{"mode",mode},{"timeout_ms",timeoutMs},{"targets",arr},{"schema_version",1}});
}
void RpcClient::telemetryPoll() { send(QStringLiteral("telemetry.poll"), {{"limit",32}}); }
void RpcClient::pollTelemetry() { if (connected()) telemetryPoll(); }

void RpcClient::handleResult(quint64 id, const QJsonValue& value) {
    if (value.isObject()) {
        const auto result = value.toObject();
        if (result.contains("schema_version") && result.contains("severity")) { m_diagnosticReport = result.toVariantMap(); emit diagnosticReportChanged(); }
        if (result.contains("runtime")) {
            const bool enabled = result.value("runtime").toObject().value("enabled").toBool(false);
            if (enabled != m_runtimeEnabled) { m_runtimeEnabled = enabled; emit runtimeStatusChanged(); }
        }
        if (result.contains("saved")) { emit resultReceived(id, QString(), QJsonDocument(result).toJson(QJsonDocument::Compact)); return; }
        emit resultReceived(id, QString(), QJsonDocument(result).toJson(QJsonDocument::Compact));
        return;
    }
    if (value.isArray()) {
        emit resultReceived(id, QString(), QJsonDocument(value.toArray()).toJson(QJsonDocument::Compact));
    }
}

void RpcClient::onReadyRead() {
    m_buffer += m_socket.readAll();
    while (true) {
        const int newline = m_buffer.indexOf('\n'); if (newline < 0) break;
        const QByteArray line = m_buffer.left(newline).trimmed(); m_buffer.remove(0, newline + 1);
        if (line.isEmpty()) continue;
        QJsonParseError parseError{}; const QJsonDocument doc = QJsonDocument::fromJson(line, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) { emit errorOccurred(QStringLiteral("Некорректный RPC ответ")); continue; }
        const QJsonObject obj = doc.object();
        if (obj.contains("error")) { emit errorOccurred(obj.value("error").toObject().value("message").toString()); continue; }
        const quint64 id = static_cast<quint64>(obj.value("id").toInteger());
        const QJsonValue value = obj.value("result");

        if (value.isArray() && id > 0) {
            const QVariantList list = value.toArray().toVariantList();
            if (!list.isEmpty() && list.first().toMap().contains("timestamp")) { m_history = list; emit historyChanged(); }
            else if (list.isEmpty() || list.first().toMap().contains("preferred_action")) { m_profiles = list; emit profilesChanged(); }
            else {
                m_telemetry = list;
                emit telemetryChanged();
            }
        } else {
            handleResult(id, value);
        }
    }
}

void RpcClient::onSocketError(QAbstractSocket::SocketError) {
    m_telemetryTimer.stop();
    emit connectedChanged();
    emit errorOccurred(m_socket.errorString());
}
