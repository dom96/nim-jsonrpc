import json, asyncdispatch, asyncnet, tables

type
  AsyncRpcServer* = ref object
    socket: AsyncSocket
    procs: Table[string, RpcProc]

  RpcProc* = proc (params: JsonNode): Future[JsonNode]

  RpcProcError* = ref object of Exception
    code*: int
    data*: JsonNode

proc newAsyncRpcServer*(): AsyncRpcServer =
  ## Create a new ``AsyncRpcServer`` instance.
  AsyncRpcServer(
    socket: newAsyncSocket(),
    procs: initTable[string, RpcProc]()
  )

proc register*(self: AsyncRpcServer, name: string, prc: RpcProc) =
  ## Register a procedure with the specified ``AsyncRpcServer`` instance.
  self.procs[name] = prc

proc assertParam*(params: JsonNode, name: string, kind: JsonNodeKind) =
  if params.kind != JObject:
    raise RpcProcError(code: -32602, msg: "Invalid params",
                       data: newJNull())

  if not params.hasKey(name):
    raise RpcProcError(code: -32602, msg: "Invalid params",
                       data: newJNull())

  if params[name].kind != kind:
    raise RpcProcError(code: -32602, msg: "Invalid params",
                       data: newJNull())

proc replyWrap(value: JsonNode, error: JsonNode, id: JsonNode): JsonNode =
  return %{"jsonrpc": %"2.0","result": value, "error": error, "id": id}

proc sendError(client: AsyncSocket, code: int, msg: string,
               data: JsonNode, id: JsonNode = newJNull()): Future[void] =
  let error = %{"code": %(code), "message": %msg, "data": data}
  result = client.send($replyWrap(newJNull(), error, id) & "\c\l")

proc processMessage(self: AsyncRpcServer, client: AsyncSocket,
                    line: string) {.async.} =
  let node = parseJson(line)
  assert node.hasKey("jsonrpc")
  assert node["jsonrpc"].str == "2.0"

  let methodName = node["method"].str
  let id = node["id"]
  # TODO: Notifications.

  if not self.procs.hasKey(methodName):
    await client.sendError(-32601, "Method not found",
        %(methodName & " not registered."), id)
    return

  # TODO: Param verification.
  let callRes = await self.procs[methodName](node["params"])
  await client.send($replyWrap(callRes, newJNull(), id) & "\c\l")

proc processClient(self: AsyncRpcServer, client: AsyncSocket) {.async.} =
  while true:
    let line = await client.recvLine()
    if line == "":
      # Disconnected.
      client.close()
      break

    let fut = processMessage(self, client, line)
    await fut
    if fut.failed:
      if fut.readError of JsonParsingError:
        await client.sendError(-32700, "Parse error", %getCurrentExceptionMsg())
      elif fut.readError of RpcProcError:
        # This error signifies that the proc wants us to respond with a custom
        # error object.
        let err = fut.readError.RpcProcError
        await client.sendError(err.code, err.msg, err.data)
      else:
        await client.sendError(-32000, "Error", %getCurrentExceptionMsg())

proc serve*(self: AsyncRpcServer, port: Port, address = "") {.async.} =
  ## Begins accepting connections on the specified port and address.
  self.socket.bindAddr(port, address)
  self.socket.listen()

  while true:
    let client = await self.socket.accept()
    asyncCheck processClient(self, client)
