import std/[os]
import misc/[custom_logger, custom_async, regex]
import filesystem

{.push gcsafe.}
{.push raises: [].}

logCategory "fs-desktop"

type FileSystemDesktop* = ref object of FileSystem
  appDir*: string

method init*(self: FileSystemDesktop, appDir: string) =
  self.appDir = appDir

method loadFile*(self: FileSystemDesktop, path: string): string =
  try:
    return readFile(path)
  except IOERror:
    log lvlError, &"Failed to load file {path}: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"
    return ""

method saveFile*(self: FileSystemDesktop, path: string, content: string) =
  try:
    writeFile(path, content)
  except IOError:
    log lvlError, &"Failed to write file {path}: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"

proc getApplicationDirectoryListingSync*(self: FileSystemDesktop, path: string):
    tuple[files: seq[string], folders: seq[string]] =

  try:
    let path = self.getApplicationFilePath path
    for (kind, file) in walkDir(path, relative=true):
      case kind
      of pcFile:
        result.files.add path // file
      of pcDir:
        result.folders.add path // file
      else:
        log lvlError, &"getApplicationDirectoryListing: Unhandled file type {kind} for {file}"
  except:
    discard

method getApplicationDirectoryListing*(self: FileSystemDesktop, path: string):
    Future[tuple[files: seq[string], folders: seq[string]]] {.async.} =
  return self.getApplicationDirectoryListingSync(path)

method getApplicationFilePath*(self: FileSystemDesktop, name: string): string =
  if isAbsolute(name):
    return name
  else:
    return self.appDir / name

method loadApplicationFile*(self: FileSystemDesktop, name: string): string =
  let path = self.getApplicationFilePath name
  log lvlInfo, fmt"loadApplicationFile1 {name} -> {path}"
  try:
    return readFile(path)
  except:
    log lvlError, &"Failed to load application file {path}: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"
    return ""

proc loadFileThread(args: tuple[path: string, data: ptr string, ok: ptr bool]) =
  try:
    args.data[] = readFile(args.path)
    args.ok[] = true
  except:
    args.ok[] = false

method loadFileAsync*(self: FileSystemDesktop, path: string): Future[string] {.async.} =
  log lvlInfo, fmt"loadFile '{path}'"
  try:
    var data = ""
    var ok = false
    await spawnAsync(loadFileThread, (path, data.addr, ok.addr))
    if not ok:
      log lvlError, &"Failed to load file '{path}'"
      return ""

    return data.move
  except:
    log lvlError, &"Failed to load application file {path}: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"
    return ""

method loadApplicationFileAsync*(self: FileSystemDesktop, name: string): Future[string] {.async.} =
  let path = self.getApplicationFilePath name
  log lvlInfo, fmt"loadApplicationFile2 {name} -> {path}"
  try:
    var data = ""
    var ok = false
    await spawnAsync(loadFileThread, (path, data.addr, ok.addr))
    if not ok:
      log lvlError, &"Failed to load file '{path}'"
      return ""

    return data.move
  except:
    log lvlError, &"Failed to load application file {path}: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"
    return ""

method saveApplicationFile*(self: FileSystemDesktop, name: string, content: string) =
  let path = self.getApplicationFilePath name
  log lvlInfo, fmt"saveApplicationFile {name} -> {path}"
  try:
    writeFile(path, content)
  except:
    log lvlError, &"Failed to save application file {path}: {getCurrentExceptionMsg()}\n{getCurrentException().getStackTrace()}"

proc findFilesRec(dir: string, filename: Regex, maxResults: int, res: var seq[string]) =
  try:
    for (kind, path) in walkDir(dir, relative=false):
      case kind
      of pcFile:
        if path.contains(filename):
          res.add path
          if res.len >= maxResults:
            return

      of pcDir:
        findFilesRec(path, filename, maxResults, res)
        if res.len >= maxResults:
          return
      else:
        discard

  except:
    discard

proc findFileThread(args: tuple[root: string, filename: string, maxResults: int, res: ptr seq[string]]) =
  try:
    let filenameRegex = re(args.filename)
    findFilesRec(args.root, filenameRegex, args.maxResults, args.res[])
  except RegexError:
    discard

method findFile*(self: FileSystemDesktop, root: string, filenameRegex: string, maxResults: int = int.high): Future[seq[string]] {.async.} =
  var res = newSeq[string]()
  await spawnAsync(findFileThread, (root, filenameRegex, maxResults, res.addr))
  return res

method copyFile*(self: FileSystemDesktop, source: string, dest: string): Future[bool] {.async.} =
  try:
    let dir = dest.splitPath.head
    createDir(dir)
    copyFileWithPermissions(source, dest)
    return true
  except:
    log lvlError, &"Failed to copy file '{source}' to '{dest}': {getCurrentExceptionMsg()}"
    return false
