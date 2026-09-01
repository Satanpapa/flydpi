import QtQuick

QtObject {
    signal replyReceived(int id, string method, string payload)
    signal rpcError(string message)

    property int nextId: 1
    property string endpoint: "http://127.0.0.1:27654/rpc"

    function call(method, params) {
        const id = nextId++
        const xhr = new XMLHttpRequest()
        xhr.open("POST", endpoint)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status < 200 || xhr.status >= 300) {
                rpcError("RPC HTTP " + xhr.status)
                return
            }
            try {
                const obj = JSON.parse(xhr.responseText)
                if (obj.error) {
                    rpcError(obj.error.message || "RPC error")
                } else {
                    replyReceived(id, method, JSON.stringify(obj.result || {}))
                }
            } catch (e) {
                rpcError("Invalid RPC response")
            }
        }
        xhr.send(JSON.stringify({jsonrpc:"2.0", id:id, method:method, params:params || {}}))
    }
}
