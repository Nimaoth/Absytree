import std/[options, os]
import misc/util
import workspaces/[workspace]
import platform/[filesystem]

type Document* = ref object of RootObj
  appFile*: bool                        ## Whether this is an application file (e.g. stored in local storage on the browser)
  isBackedByFile*: bool = false
  filename*: string
  workspace*: Option[Workspace]   ## The workspace this document belongs to
  revision*: int
  undoableRevision*: int
  lastSavedRevision*: int               ## Undobale revision at the time we saved the last time

method `$`*(document: Document): string {.base.} = return ""
method save*(self: Document, filename: string = "", app: bool = false) {.base.} = discard
method load*(self: Document, filename: string = "") {.base.} = discard
method deinit*(self: Document) {.base.} = discard
method getStatisticsString*(self: Document): string {.base.} = discard

proc fullPath*(self: Document): string =
  if not self.isBackedByFile:
    return self.filename

  if self.filename.isAbsolute:
    return self.filename
  if self.workspace.getSome(ws):
    return ws.getWorkspacePath() / self.filename
  if self.appFile:
    return fs.getApplicationFilePath(self.filename)

  when not defined(js):
    return self.filename.absolutePath
  else:
    return self.filename