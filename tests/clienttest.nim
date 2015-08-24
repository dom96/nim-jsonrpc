import jsonrpc/client, asyncdispatch, json

proc main() {.async.} =
  # Create a new instance of the server.
  var rpcClient = newAsyncRpcClient()
  # Connect to the server.
  await rpcClient.connect("localhost", Port(5678))

  # Call some procedures defined on the server.
  var response = await(rpcClient.call("add", %{"x": %123, "y": %500}))
  assert(response.error == false)
  assert(response.result.num == 623)

  # Call some procedures undefined on the server
  response = await(rpcClient.call("minus", %{"x": %123, "y": %500}))
  assert(response.error == true)
  assert(response.result["code"].num == -32601)

waitFor main()
