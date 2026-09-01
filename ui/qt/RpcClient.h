#pragma once

#include <QObject>
#include <QTcpSocket>
#include <QVariantList>
#include <QVariantMap>
#include <QJsonObject>

class RpcClient final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QVariantMap diagnosticReport READ diagnosticReport NOTIFY diagnosticReportChanged)
    Q_PROPERTY(QVariantList history READ history NOTIFY historyChanged)
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY profilesChanged)
public:
    explicit RpcClient(QObject* parent = nullptr);
    bool connected() const;
    QVariantMap diagnosticReport() const;
    QVariantList history() const;
    QVariantList profiles() const;

    Q_INVOKABLE void connectToOrchestrator();
    Q_INVOKABLE void statusGet();
    Q_INVOKABLE void probeRun(const QStringList& targets = {});
    Q_INVOKABLE void historyList();
    Q_INVOKABLE void profileList();
    Q_INVOKABLE void saveProfile(const QString& name, const QString& action, const QString& mode, int timeoutMs, const QStringList& targets);

signals:
    void connectedChanged();
    void resultReceived(quint64 id, const QString& method, const QString& json);
    void errorOccurred(const QString& message);
    void diagnosticReportChanged();
    void historyChanged();
    void profilesChanged();

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
    QVariantList m_history;
    QVariantList m_profiles;
};
