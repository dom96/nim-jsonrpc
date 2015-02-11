import jsonrpc/client, asyncdispatch, json

proc main() {.async.} =
  var rpcClient = newAsyncRpcClient()
  await rpcClient.connect("localhost", Port(5678))

  assert(await(rpcClient.call("add", %{"x": %123, "y": %500})).num == 623)
  assert(await(rpcClient.call("add", %{"x": %5, "y": %23})).num == 28)

waitFor main()
