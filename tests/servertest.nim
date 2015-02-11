import jsonrpc/server, asyncdispatch, json

proc add(params: JsonNode): Future[JsonNode] {.async.} =
  assertParam(params, "x", JInt)
  assertParam(params, "y", JInt)
  return %(params["x"].num + params["y"].num)

when isMainModule:
  var rpcServer = newAsyncRpcServer()
  rpcServer.register("add", add)
  waitFor rpcServer.serve(Port(5678))
