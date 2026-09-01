#include "RpcClient.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>

RpcClient::RpcClient(QObject* parent) : QObject(parent) {
    connect(&m_socket, &QTcpSocket::connected, this, &RpcClient::onConnected);
    connect(&m_socket, &QTcpSocket::readyRead, this, &RpcClient::onReadyRead);
    connect(&m_socket, &QTcpSocket::errorOccurred, this, &RpcClient::onSocketError);
}

bool RpcClient::connected() const { return m_socket.state() == QAbstractSocket::ConnectedState; }

void RpcClient::connectToOrchestrator() {
    if (!connected()) m_socket.connectToHost(QStringLiteral("127.0.0.1"), 27654);
}

void RpcClient::onConnected() { emit connectedChanged(); statusGet(); }

void RpcClient::send(const QString& method, const QJsonObject& params) {
    if (!connected()) { emit errorOccurred(QStringLiteral("Оркестратор недоступен")); return; }
    const quint64 id = m_nextId++;
    QJsonObject req{{"jsonrpc", "2.0"}, {"id", static_cast<qint64>(id)}, {"method", method}, {"params", params}};
    m_socket.write(QJsonDocument(req).toJson(QJsonDocument::Compact) + '\n');
}

void RpcClient::statusGet() { send(QStringLiteral("status.get"), {}); }

void RpcClient::probeRun(const QStringList& targets) {
    QJsonArray a; for (const auto& t : targets) a.append(t);
    send(QStringLiteral("probe.run"), {{"targets", a}});
}

void RpcClient::onReadyRead() {
    m_buffer += m_socket.readAll();
    while (true) {
        const int nl = m_buffer.indexOf('\n');
        if (nl < 0) break;
        const QByteArray line = m_buffer.left(nl).trimmed();
        m_buffer.remove(0, nl + 1);
        if (line.isEmpty()) continue;
        QJsonParseError pe{};
        const QJsonDocument doc = QJsonDocument::fromJson(line, &pe);
        if (pe.error != QJsonParseError::NoError || !doc.isObject()) { emit errorOccurred(QStringLiteral("Некорректный RPC ответ")); continue; }
        const QJsonObject obj = doc.object();
        if (obj.contains("error")) { emit errorOccurred(obj.value("error").toObject().value("message").toString()); continue; }
        emit resultReceived(static_cast<quint64>(obj.value("id").toInteger()), QJsonDocument(obj.value("result").toObject()).toJson(QJsonDocument::Compact));
    }
}

void RpcClient::onSocketError(QAbstractSocket::SocketError) {
    emit connectedChanged();
    emit errorOccurred(m_socket.errorString());
}
