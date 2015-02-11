import jsonrpc/server, asyncdispatch, json

proc add(params: JsonNode): Future[JsonNode] {.async.} =
  ## Simply adds two numbers together.
  assertParam(params, "x", JInt)
  assertParam(params, "y", JInt)
  return %(params["x"].num + params["y"].num)

when isMainModule:
  var rpcServer = newAsyncRpcServer()
  # Register the ``add`` procedure with the server instance.
  rpcServer.register("add", add)
  # Listen for connections.
  waitFor rpcServer.serve(Port(5678))
