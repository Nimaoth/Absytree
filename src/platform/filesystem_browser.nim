import std/[dom, tables]
import filesystem, custom_async

type FileSystemBrowser* = ref object of FileSystem
  discard

proc loadFileSync(path: cstring): cstring {.importc, nodecl.}
proc loadFileSyncBinary(path: cstring): Future[ArrayBuffer] {.importc, nodecl.}

method loadFile*(self: FileSystemBrowser, path: string): string =
  return $loadFileSync(path.cstring)

method saveFile*(self: FileSystemBrowser, path: string, content: string) =
  discard

proc localStorageHasItem(name: cstring): bool {.importjs: "(window.localStorage.getItem(#) !== null)".}

var cachedAppFiles = initTable[string, string]()

method loadApplicationFile*(self: FileSystemBrowser, name: string): string =
  if localStorageHasItem(name.cstring):
    return $window.localStorage.getItem(name.cstring)
  if not cachedAppFiles.contains(name):
    cachedAppFiles[name] = $loadFileSync(name.cstring)
  return cachedAppFiles[name]

method loadApplicationFileBinary*(self: FileSystemBrowser, name: string): Future[ArrayBuffer] =
  return loadFileSyncBinary(name.cstring)

method saveApplicationFile*(self: FileSystemBrowser, name: string, content: string) =
  window.localStorage.setItem(name.cstring, content.cstring)