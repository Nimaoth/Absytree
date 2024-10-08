{.used.}

import std/[strutils, os]
import misc/[custom_async, array_buffer]

{.push gcsafe.}
{.push raises: [].}

type FileSystem* = ref object of RootObj
  discard

method init*(self: FileSystem, appDir: string) {.base.} = discard

method loadFile*(self: FileSystem, path: string): string {.base.} = discard
method loadFileAsync*(self: FileSystem, path: string): Future[string] {.base.} = discard
method loadFileBinaryAsync*(self: FileSystem, name: string): Future[ArrayBuffer] {.base.} = discard

method saveFile*(self: FileSystem, path: string, content: string) {.base.} = discard

method getApplicationDirectoryListing*(self: FileSystem, path: string):
  Future[tuple[files: seq[string], folders: seq[string]]] {.base.} = discard
method getApplicationFilePath*(self: FileSystem, name: string): string {.base.} = discard
method loadApplicationFile*(self: FileSystem, name: string): string {.base.} = discard
method loadApplicationFileAsync*(self: FileSystem, name: string): Future[string] {.base.} = "".toFuture
method saveApplicationFile*(self: FileSystem, name: string, content: string) {.base.} = discard

method findFile*(self: FileSystem, root: string, filenameRegex: string, maxResults: int = int.high): Future[seq[string]] {.base.} = discard

method copyFile*(self: FileSystem, source: string, dest: string): Future[bool] {.base.} = discard

proc normalizePathUnix*(path: string): string =
  var stripLeading = false
  if path.startsWith("/") and path.len >= 3 and path[2] == ':':
    # Windows path: /C:/...
    stripLeading = true
  result = path.normalizedPath.replace('\\', '/').strip(leading=stripLeading, chars={'/'})
  if result.len >= 2 and result[1] == ':':
    result[0] = result[0].toUpperAscii

proc `//`*(a: string, b: string): string = (a / b).normalizePathUnix

import filesystem_desktop

let fs*: FileSystem = new FileSystemDesktop
fs.init getAppDir()
