#include "RpcClient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

RpcClient::RpcClient(QObject* parent) : QObject(parent) {
    connect(&m_socket, &QTcpSocket::connected, this, &RpcClient::onConnected);
    connect(&m_socket, &QTcpSocket::readyRead, this, &RpcClient::onReadyRead);
    connect(&m_socket, &QTcpSocket::errorOccurred, this, &RpcClient::onSocketError);
}

bool RpcClient::connected() const {
    return m_socket.state() == QAbstractSocket::ConnectedState;
}

QVariantMap RpcClient::diagnosticReport() const {
    return m_diagnosticReport;
}

void RpcClient::connectToOrchestrator() {
    if (connected()) return;
    m_socket.connectToHost(QStringLiteral("127.0.0.1"), 27654);
}

void RpcClient::onConnected() {
    emit connectedChanged();
    statusGet();
}

void RpcClient::send(const QString& method, const QJsonObject& params) {
    if (!connected()) {
        emit errorOccurred(QStringLiteral("Оркестратор недоступен"));
        return;
    }
    const quint64 id = m_nextId++;
    QJsonObject request{
        {QStringLiteral("jsonrpc"), QStringLiteral("2.0")},
        {QStringLiteral("id"), static_cast<qint64>(id)},
        {QStringLiteral("method"), method},
        {QStringLiteral("params"), params}
    };
    m_socket.write(QJsonDocument(request).toJson(QJsonDocument::Compact) + '\n');
}

void RpcClient::statusGet() {
    send(QStringLiteral("status.get"), {});
}

void RpcClient::probeRun(const QStringList& targets) {
    QJsonArray array;
    for (const auto& target : targets) array.append(target);
    QJsonObject params;
    if (!targets.isEmpty()) params.insert(QStringLiteral("targets"), array);
    send(QStringLiteral("diagnostic.run"), params);
}

void RpcClient::handleResult(quint64 id, const QJsonObject& result) {
    if (result.contains(QStringLiteral("schema_version")) && result.contains(QStringLiteral("severity"))) {
        m_diagnosticReport = result.toVariantMap();
        emit diagnosticReportChanged();
    }
    emit resultReceived(id, QString(), QJsonDocument(result).toJson(QJsonDocument::Compact));
}

void RpcClient::onReadyRead() {
    m_buffer += m_socket.readAll();
    while (true) {
        const int newline = m_buffer.indexOf('\n');
        if (newline < 0) break;
        const QByteArray line = m_buffer.left(newline).trimmed();
        m_buffer.remove(0, newline + 1);
        if (line.isEmpty()) continue;

        QJsonParseError parseError{};
        const QJsonDocument doc = QJsonDocument::fromJson(line, &parseError);
        if (parseError.error != QJsonParseError::NoError || !doc.isObject()) {
            emit errorOccurred(QStringLiteral("Некорректный RPC ответ"));
            continue;
        }
        const QJsonObject obj = doc.object();
        if (obj.contains(QStringLiteral("error"))) {
            emit errorOccurred(obj.value(QStringLiteral("error")).toObject().value(QStringLiteral("message")).toString());
            continue;
        }
        const quint64 id = static_cast<quint64>(obj.value(QStringLiteral("id")).toInteger());
        handleResult(id, obj.value(QStringLiteral("result")).toObject());
    }
}

void RpcClient::onSocketError(QAbstractSocket::SocketError) {
    emit connectedChanged();
    emit errorOccurred(m_socket.errorString());
}
