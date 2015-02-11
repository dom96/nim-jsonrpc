import json, asyncdispatch, asyncnet, tables

type
  AsyncRpcServer* = ref object
    socket: AsyncSocket
    procs: Table[string, RpcProc]

  RpcProc* = proc (params: JsonNode): Future[JsonNode]

proc newAsyncRpcServer*(): AsyncRpcServer =
  ## Create a new ``AsyncRpcServer`` instance.
  new result
  result.socket = newAsyncSocket()
  result.procs = initTable[string, RpcProc]()

proc register*(self: AsyncRpcServer, name: string, prc: RpcProc) =
  ## Register a procedure with the specified ``AsyncRpcServer`` instance.
  self.procs[name] = prc

proc sendError(client: AsyncSocket, code: int, msg: string,
               data: string, id: JsonNode = newJNull()): Future[void] =
  let error = %{"jsonrpc": %"2.0",
      "error": %{"code": %(code), "message": %msg,
                 "data": %data, "id": id}}
  result = client.send($error & "\c\l")

proc processMessage(self: AsyncRpcServer, client: AsyncSocket,
                    line: string) {.async.} =
  try:
    let node = parseJson(line)
    assert node.hasKey("jsonrpc")
    assert node["jsonrpc"].str == "2.0"

    let methodName = node["method"].str
    let id = node["id"]

    if not self.procs.hasKey(methodName):
      await client.sendError(-32601, "Method not found",
          methodName & " not registered.", id)
      return

    # TODO: Param verification.
    let callRes = await self.procs[methodName](node["params"])
    let reply = %{"jsonrpc": %"2.0", "result": callRes, "id": id}
    await client.send($reply & "\c\l")

  except JsonParsingError:
    echo 34
    #await client.sendError(-32700, "Parse error", getCurrentExceptionMsg())
  except:
    echo 34
    #await client.sendError(-32000, "Error", getCurrentExceptionMsg())
