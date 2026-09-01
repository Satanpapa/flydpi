#pragma once

#include <QObject>
#include <QTcpSocket>

class RpcClient final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)

public:
    explicit RpcClient(QObject* parent = nullptr);

    bool connected() const;

    Q_INVOKABLE void connectToOrchestrator();
    Q_INVOKABLE void statusGet();
    Q_INVOKABLE void probeRun(const QStringList& targets);

signals:
    void connectedChanged();
    void resultReceived(quint64 id, const QString& method, const QString& json);
    void errorOccurred(const QString& message);

private slots:
    void onConnected();
    void onReadyRead();
    void onSocketError(QAbstractSocket::SocketError error);

private:
    void send(const QString& method, const QJsonObject& params);

    QTcpSocket m_socket;
    quint64 m_nextId{1};
    QByteArray m_buffer;
};
