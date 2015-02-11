import jsonrpc/client, asyncdispatch, json

proc main() {.async.} =
  # Create a new instance of the server.
  var rpcClient = newAsyncRpcClient()
  # Connect to the server.
  await rpcClient.connect("localhost", Port(5678))

  # Call some procedures defined on the server.
  assert(await(rpcClient.call("add", %{"x": %123, "y": %500})).num == 623)
  assert(await(rpcClient.call("add", %{"x": %5, "y": %23})).num == 28)

waitFor main()
