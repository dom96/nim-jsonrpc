import json, asyncdispatch, asyncnet, oids, future, tables

type
  AsyncRpcClient* = ref object
    socket: AsyncSocket
    awaitingIDs: Table[string, Future[Response]]
    address: string
    port: Port
  Response = tuple[error: bool, result: JsonNode]

proc newAsyncRpcClient*(): AsyncRpcClient =
  ## Creates a new ``AsyncRpcClient`` instance. 
  AsyncRpcClient(
    socket: newAsyncSocket(),
    awaitingIDs: initTable[string, Future[Response]]()
  )

proc call*(self: AsyncRpcClient, name: string,
           params: JsonNode): Future[Response] {.async.} =
  ## Remotely calls the specified RPC method.
  ##
  ## The result of this call is returned.
  let id = $genOid()
  let msg = %{"jsonrpc": %"2.0", "method": %name, "params": params, "id": %id}
  await self.socket.send($msg & "\c\l")

  # This Future will be completed by ``processMessage``.
  var idFut = newFuture[Response]()
  self.awaitingIDs[id] = idFut
  result = await idFut

proc processMessage(self: AsyncRpcClient, line: string) =
  let node = parseJson(line)
  assert node.hasKey("jsonrpc")
  assert node["jsonrpc"].str == "2.0"

  assert node.hasKey("id")
  assert self.awaitingIDs.hasKey(node["id"].str)

  if node["error"].kind == JNull:
    self.awaitingIDs[node["id"].str].complete((false, node["result"]))
  else:
    self.awaitingIDs[node["id"].str].complete((true, node["error"]))

proc connect*(self: AsyncRpcClient, address: string, port: Port): Future[void]
proc processData(self: AsyncRpcClient) {.async.} =
  while true:
    let line = await self.socket.recvLine()

    if line == "":
      # We have been disconnected.
      self.socket.close()
      self.socket = newAsyncSocket()
      break
    
    processMessage(self, line)

  await connect(self, self.address, self.port)

proc connect(self: AsyncRpcClient, address: string, port: Port): Future[void] =
  ## Connects to the specified RPC server.

  # TODO: Workaround for a little bug in Nim's compiler.
  proc connectEx(self: AsyncRpcClient, address: string, port: Port) {.async.} =
    await self.socket.connect(address, port)
    self.address = address
    self.port = port

    asyncCheck processData(self)
  result = connectEx(self, address, port)
