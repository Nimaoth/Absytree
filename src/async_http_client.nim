import std/[options]
import custom_async, array_buffer

when defined(js):

  proc jsGetAsync(url: cstring, authToken: cstring): Future[cstring] {.importc.}
  proc jsPostAsync(url: cstring, content: cstring, authToken: cstring): Future[void] {.importc.}
  proc jsPostBinaryAsync(url: cstring, content: ArrayBuffer, authToken: cstring): Future[void] {.importc.}

  proc httpGet*(url: string, authToken: Option[string] = string.none): Future[string] {.async.} =
    let cstr = await jsGetAsync(url.cstring, authToken.get("").cstring)
    return $cstr

  proc httpPost*(url: string, content: string, authToken: Option[string] = string.none): Future[void] {.async.} =
    await jsPostAsync(url.cstring, content.cstring, authToken.get("").cstring)

  proc httpPost*(url: string, content: ArrayBuffer, authToken: Option[string] = string.none): Future[void] {.async.} =
    await jsPostBinaryAsync(url.cstring, content, authToken.get("").cstring)

else:
  import std/[httpclient]

  var clients: seq[AsyncHttpClient] = @[]
  var totalClients = 0
  const maxClients = 25

  proc getClient(): Future[AsyncHttpClient] {.async.} =
    while clients.len == 0:
      if totalClients < maxClients:
        inc totalClients
        return newAsyncHttpClient(userAgent = "Thunder Client (https://www.thunderclient.com)")
      await sleepAsync(1)
    return clients.pop

  template withClient(client, body: untyped): untyped =
    block:
      let client = await getClient()
      defer:
        clients.add client
      body

  proc httpGet*(url: string, authToken: Option[string] = string.none): Future[string] {.async.} =
    var headers = newHttpHeaders()
    if authToken.isSome:
      headers.add("Authorization", authToken.get)

    withClient client:
      var response = await client.request(url, HttpGet, headers=headers)
      let body = await response.body
      return body

  proc httpPost*(url: string, content: string, authToken: Option[string] = string.none): Future[void] {.async.} =
    var headers = newHttpHeaders()
    if authToken.isSome:
      headers.add("Authorization", authToken.get)

    headers.add("content-type", "text/plain")

    withClient client:
      discard await client.request(url, HttpPost, body=content, headers=headers)

  proc httpPost*(url: string, content: ArrayBuffer, authToken: Option[string] = string.none): Future[void] {.async.} =
    var str = newStringOfCap(content.buffer.len)
    str.setLen(content.buffer.len)
    for i in 0..content.buffer.high:
      str[i] = content.buffer[i].char

    var headers = newHttpHeaders()
    if authToken.isSome:
      headers.add("Authorization", authToken.get)

    headers.add("content-type", "application/octet-stream")

    withClient client:
      discard await client.request(url, HttpPost, body=str, headers=headers)