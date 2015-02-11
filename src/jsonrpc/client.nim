import json, asyncdispatch, asyncnet, oids, future, tables

type
  AsyncRpcClient* = ref object
    socket: AsyncSocket
    awaitingIDs: Table[string, Future[JsonNode]]
    address: string
    port: Port

proc newAsyncRpcClient*(): AsyncRpcClient =
  ## Creates a new ``AsyncRpcClient`` instance. 
  AsyncRpcClient(
    socket: newAsyncSocket(),
    awaitingIDs: initTable[string, Future[JsonNode]]()
  )

proc call*(self: AsyncRpcClient, name: string,
           params: JsonNode): Future[JsonNode] {.async.} =
  ## Remotely calls the specified RPC method.
  ##
  ## The result of this call is returned.
  let id = $genOid()
  let msg = %{"jsonrpc": %"2.0", "method": %name, "params": params, "id": %id}
  await self.socket.send($msg & "\c\l")

  # This Future will be completed by ``processMessage``.
  var idFut = newFuture[JsonNode]()
  self.awaitingIDs[id] = idFut
  result = await idFut

proc processMessage(self: AsyncRpcClient, line: string) =
  let node = parseJson(line)
  assert node.hasKey("jsonrpc")
  assert node["jsonrpc"].str == "2.0"

  assert node.hasKey("id")
  assert self.awaitingIDs.hasKey(node["id"].str)
  self.awaitingIDs[node["id"].str].complete(node["result"])

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
