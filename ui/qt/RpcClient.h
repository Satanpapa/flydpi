#pragma once

#include <QObject>
#include <QTcpSocket>
#include <QVariantMap>
#include <QJsonObject>

class RpcClient final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QVariantMap diagnosticReport READ diagnosticReport NOTIFY diagnosticReportChanged)

public:
    explicit RpcClient(QObject* parent = nullptr);

    bool connected() const;
    QVariantMap diagnosticReport() const;

    Q_INVOKABLE void connectToOrchestrator();
    Q_INVOKABLE void statusGet();
    Q_INVOKABLE void probeRun(const QStringList& targets = {});

signals:
    void connectedChanged();
    void resultReceived(quint64 id, const QString& method, const QString& json);
    void errorOccurred(const QString& message);
    void diagnosticReportChanged();

private slots:
    void onConnected();
    void onReadyRead();
    void onSocketError(QAbstractSocket::SocketError error);

private:
    void send(const QString& method, const QJsonObject& params);
    void handleResult(quint64 id, const QJsonObject& result);

    QTcpSocket m_socket;
    quint64 m_nextId{1};
    QByteArray m_buffer;
    QVariantMap m_diagnosticReport;
};
