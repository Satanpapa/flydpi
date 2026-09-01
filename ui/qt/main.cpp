#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QUrl>
#include "RpcClient.h"

int main(int argc, char* argv[]) {
    QGuiApplication app(argc, argv);
    RpcClient rpc;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty(QStringLiteral("rpcClient"), &rpc);
    engine.load(QUrl(QStringLiteral("qrc:/qml/Main.qml")));
    if (engine.rootObjects().isEmpty()) return 1;
    rpc.connectToOrchestrator();
    return app.exec();
}
