import std/[strutils, logging, sequtils, sugar]
import editor, input, document, document_editor, events
import scripting_api except DocumentEditor, TextDocumentEditor, AstDocumentEditor

var logger = newConsoleLogger()

type TextDocument* = ref object of Document
  filename*: string
  content*: seq[string]

  textChanged*: (document: TextDocument) -> void
  singleLine*: bool

type TextDocumentEditor* = ref object of DocumentEditor
  editor*: Editor
  document*: TextDocument
  selection: Selection

func selection*(self: TextDocumentEditor): Selection = self.selection

proc newTextDocument*(filename: string = ""): TextDocument =
  new(result)
  result.filename = filename

method `$`*(document: TextDocument): string =
  return document.filename

proc contentString*(doc: TextDocument): string = doc.content.join

proc lineLength(self: TextDocument, line: int): int =
  if line < self.content.len:
    return self.content[line].len
  return 0

method save*(self: TextDocument, filename: string = "") {.locks: "unknown".} =
  self.filename = if filename.len > 0: filename else: self.filename
  if self.filename.len == 0:
    raise newException(IOError, "Missing filename")

  writeFile(self.filename, self.content.join "\n")

method load*(self: TextDocument, filename: string = "") {.locks: "unknown".} =
  let filename = if filename.len > 0: filename else: self.filename
  if filename.len == 0:
    raise newException(IOError, "Missing filename")

  self.filename = filename

  let file = readFile(self.filename)
  self.content = collect file.splitLines

proc notifyTextChanged(self: TextDocument) =
  if self.textChanged != nil:
    self.textChanged self

proc delete(self: TextDocument, selection: Selection, notify: bool = true): Cursor =
  if selection.isEmpty:
    return selection.first

  let (first, last) = selection.normalized
  # echo "delete: ", selection, ", content = ", self.content
  if first.line == last.line:
    # Single line selection
    self.content[last.line].delete first.column..<last.column
  else:
    # Multi line selection
    # Delete from first cursor to end of first line and add last line
    if first.column < self.lineLength first.line:
      self.content[first.line].delete(first.column..<(self.lineLength first.line))
    self.content[first.line].add self.content[last.line][last.column..^1]
    # Delete all lines in between
    self.content.delete (first.line + 1)..last.line

  if notify:
    self.notifyTextChanged()

  return selection.first

proc insert(self: TextDocument, cursor: Cursor, text: string, notify: bool = true): Cursor =
  var cursor = cursor
  var i: int = 0
  # echo "insert ", cursor, ": ", text
  if self.singleLine:
    let text = text.replace("\n", " ")
    if self.content.len == 0:
      self.content.add text
    else:
      self.content[0].insert(text, cursor.column)
    cursor.column += text.len

  else:
    for line in text.splitLines(false):
      defer: inc i
      if i > 0:
        # Split line
        self.content.insert(self.content[cursor.line][cursor.column..^1], cursor.line + 1)
        if cursor.column < self.lineLength cursor.line:
          self.content[cursor.line].delete(cursor.column..<(self.lineLength cursor.line))
        cursor = (cursor.line + 1, 0)

      if line.len > 0:
        self.content[cursor.line].insert(line, cursor.column)
        cursor.column += line.len

  if notify:
    self.notifyTextChanged()

  return cursor

proc edit(self: TextDocument, selection: Selection, text: string, notify: bool = true): Cursor =
  let selection = selection.normalized
  # echo "edit ", selection, ": ", self.content
  var cursor = self.delete(selection, false)
  # echo "after delete ", cursor, ": ", self.content
  cursor = self.insert(cursor, text)
  # echo "after insert ", cursor, ": ", self.content
  return cursor

proc lineLength(self: TextDocumentEditor, line: int): int =
  if line < self.document.content.len:
    return self.document.content[line].len
  return 0

proc clampCursor*(self: TextDocumentEditor, cursor: Cursor): Cursor =
  var cursor = cursor
  if self.document.content.len == 0:
    return (0, 0)
  cursor.line = clamp(cursor.line, 0, self.document.content.len - 1)
  cursor.column = clamp(cursor.column, 0, self.lineLength cursor.line)
  return cursor

proc clampSelection*(self: TextDocumentEditor, selection: Selection): Selection =
  return (self.clampCursor(selection.first), self.clampCursor(selection.last))

proc `selection=`*(self: TextDocumentEditor, selection: Selection) =
  self.selection = self.clampSelection selection

method canEdit*(self: TextDocumentEditor, document: Document): bool =
  if document of TextDocument: return true
  else: return false

method getEventHandlers*(self: TextDocumentEditor): seq[EventHandler] =
  return @[self.eventHandler]

method handleDocumentChanged*(self: TextDocumentEditor) {.locks: "unknown".} =
  self.selection = (self.clampCursor self.selection.first, self.clampCursor self.selection.last)

proc moveCursorColumn(self: TextDocumentEditor, cursor: Cursor, offset: int): Cursor =
  var cursor = cursor
  let column = cursor.column + offset
  if column < 0:
    if cursor.line > 0:
      cursor.line = cursor.line - 1
      cursor.column = self.lineLength cursor.line
    else:
      cursor.column = 0

  elif column > self.lineLength cursor.line:
    if cursor.line < self.document.content.len - 1:
      cursor.line = cursor.line + 1
      cursor.column = 0
    else:
      cursor.column = self.lineLength cursor.line

  else:
    cursor.column = column

  return self.clampCursor cursor

proc moveCursorLine(self: TextDocumentEditor, cursor: Cursor, offset: int): Cursor =
  var cursor = cursor
  let line = cursor.line + offset
  if line < 0:
    cursor = (0, cursor.column)
  elif line >= self.document.content.len:
    cursor = (self.document.content.len - 1, cursor.column)
  else:
    cursor.line = line
  return self.clampCursor cursor

proc moveCursorHome(self: TextDocumentEditor, cursor: Cursor, offset: int): Cursor =
  return (cursor.line, 0)

proc moveCursorEnd(self: TextDocumentEditor, cursor: Cursor, offset: int): Cursor =
  return (cursor.line, self.document.lineLength cursor.line)

proc moveCursor(self: TextDocumentEditor, cursor: string, movement: proc(doc: TextDocumentEditor, c: Cursor, off: int): Cursor, offset: int) =
  case cursor
  of "":
    self.selection.last = movement(self, self.selection.last, offset)
    self.selection.first = self.selection.last
  of "first":
    self.selection.first = movement(self, self.selection.first, offset)
  of "last":
    self.selection.last = movement(self, self.selection.last, offset)
  else:
    logger.log(lvlError, "Unknown cursor " & cursor)

proc handleAction(self: TextDocumentEditor, action: string, arg: string): EventResponse =
  # echo "[textedit] handleAction ", action, " '", arg, "'"
  case action
  of "backspace":
    if self.selection.isEmpty:
      self.selection = self.document.delete((self.moveCursorColumn(self.selection.first, -1), self.selection.first)).toSelection
    else:
      self.selection = self.document.edit(self.selection, "").toSelection
  of "delete":
    if self.selection.isEmpty:
      self.selection = self.document.delete((self.selection.first, self.moveCursorColumn(self.selection.first, 1))).toSelection
    else:
      self.selection = self.document.edit(self.selection, "").toSelection

  of "editor.insert":
    if self.document.singleLine and arg == "\n":
      return Ignored

    self.selection = self.document.edit(self.selection, arg).toSelection

  of "cursor.left": self.moveCursor(arg, moveCursorColumn, -1)
  of "cursor.right": self.moveCursor(arg, moveCursorColumn, 1)

  of "cursor.up":
    if self.document.singleLine:
      return Ignored
    self.moveCursor(arg, moveCursorLine, -1)

  of "cursor.down":
    if self.document.singleLine:
      return Ignored
    self.moveCursor(arg, moveCursorLine, 1)

  of "cursor.home": self.moveCursor(arg, moveCursorHome, 0)
  of "cursor.end": self.moveCursor(arg, moveCursorEnd, 0)

  else:
    return self.editor.handleUnknownDocumentEditorAction(self, action, arg)

  return Handled

proc handleInput(self: TextDocumentEditor, input: string): EventResponse =
  # echo "handleInput '", input, "'"
  self.selection = self.document.edit(self.selection, input).toSelection
  return Handled

method injectDependencies*(self: TextDocumentEditor, ed: Editor) =
  self.editor = ed
  self.editor.registerEditor(self)

  self.eventHandler = eventHandler(ed.getEventHandlerConfig("editor.text")):
    onAction:
      self.handleAction action, arg
    onInput:
      self.handleInput input

proc newTextEditor*(document: TextDocument, ed: Editor): TextDocumentEditor =
  let editor = TextDocumentEditor(eventHandler: nil, document: document)
  editor.init()
  if editor.document.content.len == 0:
    editor.document.content = @[""]
  editor.injectDependencies(ed)
  return editor

method createWithDocument*(self: TextDocumentEditor, document: Document): DocumentEditor =
  let editor = TextDocumentEditor(eventHandler: nil, document: TextDocument(document))
  editor.init()
  if editor.document.content.len == 0:
    editor.document.content = @[""]
  return editor

method unregister*(self: TextDocumentEditor) =
  self.editor.unregisterEditor(self)