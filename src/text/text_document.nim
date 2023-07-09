import std/[strutils, logging, sequtils, sugar, options, json, strformat, tables, sets, jsonutils]
import scripting_api except DocumentEditor, TextDocumentEditor, AstDocumentEditor
from scripting_api as api import nil
import document, document_editor, id, util, event, ../regex, custom_logger, custom_async, custom_treesitter, indent, custom_unicode
import text_language_config
import platform/[filesystem, widgets]
import language/[languages, language_server_base]
import workspaces/[workspace]
import config_provider

export document, document_editor, id

type
  UndoOpKind = enum
    Delete
    Insert
    Nested
  UndoOp = ref object
    oldSelection: seq[Selection]
    case kind: UndoOpKind
    of Delete:
      selection: Selection
    of Insert:
      cursor: Cursor
      text: string
    of Nested:
      children: seq[UndoOp]

proc `$`*(op: UndoOp): string =
  result = fmt"{{{op.kind} ({op.oldSelection})"
  if op.kind == Delete: result.add fmt", selections = {op.selection}}}"
  if op.kind == Insert: result.add fmt", selections = {op.cursor}, text: '{op.text}'}}"
  if op.kind == Nested: result.add fmt", {op.children}}}"

type StyledText* = object
  text*: string
  scope*: string
  priority*: int
  bounds*: Rect
  opacity*: Option[float]

type StyledLine* = ref object
  index*: int
  parts*: seq[StyledText]

type TextDocument* = ref object of Document
  lines*: seq[string]
  languageId*: string
  version*: int

  onLoaded*: Event[TextDocument]
  textChanged*: Event[TextDocument]
  textInserted*: Event[tuple[document: TextDocument, location: Cursor, text: string]]
  textDeleted*: Event[tuple[document: TextDocument, selection: Selection]]
  singleLine*: bool

  configProvider: ConfigProvider
  languageConfig*: Option[TextLanguageConfig]
  indentStyle*: IndentStyle

  undoOps*: seq[UndoOp]
  redoOps*: seq[UndoOp]

  tsParser: TSParser
  tsLanguage: TSLanguage
  currentTree*: TSTree
  highlightQuery: TSQuery

  languageServer*: Option[LanguageServer]
  onRequestSaveHandle*: OnRequestSaveHandle

  styledTextCache: Table[int, StyledLine]

proc getLine*(self: TextDocument, line: int): string =
  if line < self.lines.len:
    return self.lines[line]
  return ""

proc lineLength*(self: TextDocument, line: int): int =
  if line < self.lines.len:
    return self.lines[line].len
  return 0

proc lastValidIndex*(self: TextDocument, line: int): int =
  if line < self.lines.len:
    return self.lines[line].len
  return 0

proc clampCursor*(self: TextDocument, cursor: Cursor): Cursor =
  var cursor = cursor
  if self.lines.len == 0:
    return (0, 0)
  cursor.line = clamp(cursor.line, 0, self.lines.len - 1)
  cursor.column = clamp(cursor.column, 0, self.lastValidIndex cursor.line)
  return cursor

proc clampSelection*(self: TextDocument, selection: Selection): Selection = (self.clampCursor(selection.first), self.clampCursor(selection.last))
proc clampAndMergeSelections*(self: TextDocument, selections: openArray[Selection]): Selections = selections.map((s) => self.clampSelection(s)).deduplicate
proc getLanguageServer*(self: TextDocument): Future[Option[LanguageServer]] {.async.}
proc trimTrailingWhitespace*(self: TextDocument)

proc notifyTextChanged*(self: TextDocument) =
  self.textChanged.invoke self
  self.styledTextCache.clear()

proc reparseTreesitter*(self: TextDocument) =
  if self.tsParser.isNotNil:
    let strValue = self.lines.join("\n")
    if self.currentTree.isNotNil:
      self.currentTree = self.tsParser.parseString(strValue, self.currentTree.some)
    else:
      self.currentTree = self.tsParser.parseString(strValue)

proc `content=`*(self: TextDocument, value: string) =
  if self.singleLine:
    self.lines = @[value.replace("\n", "")]
    if self.lines.len == 0:
      self.lines = @[""]
    if not self.tsParser.isNil:
      self.currentTree = self.tsParser.parseString(self.lines[0])
  else:
    self.lines = value.splitLines
    if self.lines.len == 0:
      self.lines = @[""]
    if not self.tsParser.isNil:
      self.currentTree = self.tsParser.parseString(value)

  inc self.version

  self.notifyTextChanged()

proc `content=`*(self: TextDocument, value: seq[string]) =
  if self.singleLine:
    self.lines = @[value.join("")]
  else:
    self.lines = value.toSeq

  if self.lines.len == 0:
    self.lines = @[""]

  let strValue = value.join("\n")

  if not self.tsParser.isNil:
    self.currentTree = self.tsParser.parseString(strValue)

  inc self.version

  self.notifyTextChanged()

func content*(self: TextDocument): seq[string] =
  return self.lines

func contentString*(self: TextDocument): string =
  return self.lines.join("\n")

func contentString*(self: TextDocument, selection: Selection): string =
  let (first, last) = selection.normalized
  if first.line == last.line:
    return self.lines[first.line][first.column..<last.column]

  result = self.lines[first.line][first.column..^1]
  for i in (first.line + 1)..<last.line:
    result.add "\n"
    result.add self.lines[i]

  result.add "\n"
  result.add self.lines[last.line][0..<last.column]

func contentString*(self: TextDocument, selection: TSRange): string =
  return self.contentString selection.toSelection(self.lines)

func charAt*(self: TextDocument, cursor: Cursor): char =
  if cursor.line < 0 or cursor.line > self.lines.high:
    return 0.char
  if cursor.column < 0 or cursor.column > self.lines[cursor.line].high:
    return 0.char
  return self.lines[cursor.line][cursor.column]

func len*(line: StyledLine): int =
  result = 0
  for p in line.parts:
    result += p.text.len

proc runeIndex*(line: var StyledLine, index: int): RuneIndex =
  var i = 0
  for part in line.parts.mitems:
    if index >= i and index < i + part.text.len:
      result += part.text.toOpenArray.runeIndex(index - i).RuneCount
      return
    i += part.text.len
    result += part.text.toOpenArray.runeLen

proc runeLen*(line: var StyledLine): RuneCount =
  for part in line.parts.mitems:
    result += part.text.toOpenArray.runeLen

proc splitAt*(line: var StyledLine, index: RuneIndex) =
  var index = index
  var i = 0
  while i < line.parts.len and index >= line.parts[i].text.runeLen.RuneIndex:
    index -= line.parts[i].text.runeLen
    i += 1

  if i < line.parts.len and index != 0.RuneIndex and index != line.parts[i].text.runeLen.RuneIndex:
    var copy = line.parts[i]
    let byteIndex = line.parts[i].text.toOpenArray.runeOffset(index)
    line.parts[i].text = line.parts[i].text[0..<byteIndex]
    copy.text = copy.text[byteIndex..^1]
    line.parts.insert(copy, i + 1)

proc splitAt*(self: TextDocument, line: var StyledLine, index: int) =
  line.splitAt(self.lines[line.index].toOpenArray.runeIndex(index, returnLen=true))

proc findAllBounds*(str: string, line: int, regex: Regex): seq[Selection] =
  var start = 0
  while start < str.len:
    let bounds = str.findBounds(regex, start)
    if bounds.first == -1:
      break
    result.add ((line, bounds.first), (line, bounds.last + 1))
    start = bounds.last + 1

proc overrideStyle*(line: var StyledLine, first: RuneIndex, last: RuneIndex, scope: string, priority: int) =
  var index = 0.RuneIndex
  for i in 0..line.parts.high:
    if index >= first and index + line.parts[i].text.runeLen <= last and priority < line.parts[i].priority:
      line.parts[i].scope = scope
      line.parts[i].priority = priority
    index += line.parts[i].text.runeLen

proc overrideStyleAndText*(line: var StyledLine, first: RuneIndex, text: string, scope: string, priority: int, opacity: Option[float] = float.none) =
  var index = 0.RuneIndex
  for i in 0..line.parts.high:
    if index >= first and index + line.parts[i].text.runeLen <= first + text.runeLen and priority < line.parts[i].priority:
      line.parts[i].scope = scope
      line.parts[i].priority = priority
      line.parts[i].opacity = opacity

      let textOverrideFirst: RuneIndex = index - first.RuneCount
      let textOverrideLast: RuneIndex = index + (line.parts[i].text.runeLen.RuneIndex - first)
      line.parts[i].text = text[textOverrideFirst..<textOverrideLast]
    index += line.parts[i].text.runeLen

proc overrideStyle*(self: TextDocument, line: var StyledLine, first: int, last: int, scope: string, priority: int) =
  line.overrideStyle(self.lines[line.index].toOpenArray.runeIndex(first, returnLen=true), self.lines[line.index].toOpenArray.runeIndex(last, returnLen=true), scope, priority)

proc overrideStyleAndText*(self: TextDocument, line: var StyledLine, first: int, text: string, scope: string, priority: int, opacity: Option[float] = float.none) =
  line.overrideStyleAndText(self.lines[line.index].toOpenArray.runeIndex(first, returnLen=true), text, scope, priority, opacity)

proc getStyledText*(self: TextDocument, i: int): StyledLine =
  if self.styledTextCache.contains(i):
    result = self.styledTextCache[i]
  else:
    var line = self.lines[i]
    result = StyledLine(index: i, parts: @[StyledText(text: line, scope: "", priority: 1000000000)])
    self.styledTextCache[i] = result

    var regexes = initTable[string, Regex]()

    if self.tsParser.isNil or self.highlightQuery.isNil or self.currentTree.isNil:
      return

    for match in self.highlightQuery.matches(self.currentTree.root, tsRange(tsPoint(i, 0), tsPoint(i, line.len))):
      let predicates = self.highlightQuery.predicatesForPattern(match.pattern)

      for capture in match.captures:
        let scope = capture.name

        let node = capture.node

        var matches = true
        for predicate in predicates:

          if not matches:
            break

          for operand in predicate.operands:
            let value = $operand.`type`

            if operand.name != scope:
              matches = false
              break

            case $predicate.operator
            of "match?":
              let regex = if regexes.contains(value):
                regexes[value]
              else:
                let regex = re(value)
                regexes[value] = regex
                regex

              let nodeText = self.contentString(node.getRange)
              if nodeText.matchLen(regex, 0) != nodeText.len:
                matches = false
                break

            of "not-match?":
              let regex = if regexes.contains(value):
                regexes[value]
              else:
                let regex = re(value)
                regexes[value] = regex
                regex

              let nodeText = self.contentString(node.getRange)
              if nodeText.matchLen(regex, 0) == nodeText.len:
                matches = false
                break

            of "eq?":
              # @todo: second arg can be capture aswell
              let nodeText = self.contentString(node.getRange)
              if nodeText != value:
                matches = false
                break

            of "not-eq?":
              # @todo: second arg can be capture aswell
              let nodeText = self.contentString(node.getRange)
              if nodeText == value:
                matches = false
                break

            # of "any-of?":
            #   logger.log(lvlError, fmt"Unknown predicate '{predicate.name}'")

            else:
              logger.log(lvlError, fmt"Unknown predicate '{predicate.operator}'")

          if self.configProvider.getFlag("text.print-matches", false):
            let nodeText = self.contentString(node.getRange)
            logger.log(lvlInfo, fmt"{match.pattern}: '{nodeText}' {node} (matches: {matches})")

        if not matches:
          continue

        let nodeRange = node.getRange

        if nodeRange.first.row == i:
          # result.splitAt(nodeRange.first.column.RuneIndex)
          splitAt(self, result, nodeRange.first.column)
        if nodeRange.last.row == i:
          # result.splitAt(nodeRange.last.column)
          splitAt(self, result, nodeRange.last.column)

        let first = if nodeRange.first.row < i:
          0
        elif nodeRange.first.row == i:
          nodeRange.first.column
        else:
          line.len

        let last = if nodeRange.last.row < i:
          0
        elif nodeRange.last.row == i:
          nodeRange.last.column
        else:
          line.len

        if i == 0:
          debugf"{i}: first: {first}, last: {last}, scope: {scope}"
        overrideStyle(self, result, first, last, $scope, match.pattern)

    # override whitespace
    let opacity = self.configProvider.getValue("editor.text.whitespace.opacity", 0.4)
    if opacity > 0:
      let pattern = re"[ ]+"
      let ch = "·"
      let bounds = self.lines[i].findAllBounds(i, pattern)
      for s in bounds:
        result.splitAt(self.lines[i].toOpenArray.runeIndex(s.first.column, returnLen=true))
        result.splitAt(self.lines[i].toOpenArray.runeIndex(s.last.column, returnLen=true))
      for s in bounds:
        result.overrideStyleAndText(self.lines[i].toOpenArray.runeIndex(s.first.column, returnLen=true), ch.repeat(s.last.column - s.first.column), "comment", 0, opacity=opacity.some)

proc initTreesitter*(self: TextDocument): Future[void] {.async.} =
  if not self.tsParser.isNil:
    self.tsParser.deinit()
    self.tsParser = nil
  if not self.highlightQuery.isNil:
    self.highlightQuery.deinit()
    self.highlightQuery = nil

  let languageId = if getLanguageForFile(self.filename).getSome(languageId):
    languageId
  else:
    return

  let config = self.configProvider.getValue("editor.text.treesitter." & languageId, newJObject())
  var language = await loadLanguage(languageId, config)

  if language.isNone:
    logger.log(lvlWarn, fmt"Language is not available: '{languageId}'")
    return

  self.tsParser = createTSParser()
  if self.tsParser.isNil:
    logger.log(lvlWarn, fmt"Failed to create ts parser for: '{languageId}'")
    return

  self.tsParser.setLanguage(language.get)
  self.tsLanguage = language.get

  self.currentTree = self.tsParser.parseString(self.contentString)

  try:
    let queryString = fs.loadFile(fmt"./languages/{languageId}/queries/highlights.scm")
    self.highlightQuery = language.get.query(queryString)
  except CatchableError:
    logger.log(lvlError, fmt"[textedit] No highlight queries found for '{languageId}'")

  # We now have a treesitter grammar + highlight query, so retrigger rendering
  self.notifyTextChanged()

proc newTextDocument*(configProvider: ConfigProvider, filename: string = "", content: string | seq[string] = "", app: bool = false): TextDocument =
  new(result)
  var self = result
  self.filename = filename
  self.currentTree = nil
  self.appFile = app
  self.configProvider = configProvider

  self.indentStyle = IndentStyle(kind: Spaces, spaces: 2)

  asyncCheck self.initTreesitter()

  let language = getLanguageForFile(filename)
  if language.isSome:
    self.languageId = language.get

    if (let value = self.configProvider.getValue("editor.text.language." & self.languageId, newJNull()); value.kind == JObject):
      self.languageConfig = value.jsonTo(TextLanguageConfig).some

    if self.configProvider.getValue("editor.text.auto-start-language-server", false):
      asyncCheck self.getLanguageServer()

  self.content = content

proc newTextDocument*(configProvider: ConfigProvider, filename: string, app: bool, workspaceFolder: Option[WorkspaceFolder]): TextDocument =
  result = newTextDocument(configProvider, filename, "", app)
  result.workspace = workspaceFolder
  result.load()

proc destroy*(self: TextDocument) =
  if not self.tsParser.isNil:
    self.tsParser.deinit()
    self.tsParser = nil

  if self.languageServer.getSome(ls):
    ls.removeOnRequestSaveHandler(self.onRequestSaveHandle)
    ls.stop()
    self.languageServer = LanguageServer.none

method `$`*(self: TextDocument): string =
  return self.filename

method save*(self: TextDocument, filename: string = "", app: bool = false) =
  self.filename = if filename.len > 0: filename else: self.filename
  if self.filename.len == 0:
    raise newException(IOError, "Missing filename")

  self.appFile = app

  self.trimTrailingWhitespace()

  if self.workspace.getSome(ws):
    asyncCheck ws.saveFile(self.filename, self.contentString)
  elif self.appFile:
    fs.saveApplicationFile(self.filename, self.contentString)
  else:
    fs.saveFile(self.filename, self.contentString)

proc loadAsync(self: TextDocument, ws: WorkspaceFolder): Future[void] {.async.} =
  self.content = await ws.loadFile(self.filename)
  self.onLoaded.invoke self

method load*(self: TextDocument, filename: string = "") =
  let filename = if filename.len > 0: filename else: self.filename
  if filename.len == 0:
    raise newException(IOError, "Missing filename")

  self.filename = filename

  if self.workspace.getSome(ws):
    asyncCheck self.loadAsync(ws)
  elif self.appFile:
    self.content = fs.loadApplicationFile(self.filename)
    self.onLoaded.invoke self
  else:
    self.content = fs.loadFile(self.filename)
    self.onLoaded.invoke self

proc getLanguageServer*(self: TextDocument): Future[Option[LanguageServer]] {.async.} =
  let languageId = if getLanguageForFile(self.filename).getSome(languageId):
    languageId
  else:
    return LanguageServer.none

  if self.languageServer.isSome:
    return self.languageServer

  let url = self.configProvider.getValue("editor.text.languages-server.url", "")
  let port = self.configProvider.getValue("editor.text.languages-server.port", 0)
  let config = if url != "" and port != 0:
    (url, port).some
  else:
    (string, int).none

  self.languageServer = await getOrCreateLanguageServer(languageId, self.filename, config)
  if self.languageServer.getSome(ls):
    let callback = proc (targetFilename: string): Future[void] {.async.} =
      if self.languageServer.getSome(ls):
        await ls.saveTempFile(targetFilename, self.contentString)

    self.onRequestSaveHandle = ls.addOnRequestSaveHandler(self.filename, callback)
  return self.languageServer

proc byteOffset*(self: TextDocument, cursor: Cursor): int =
  result = cursor.column
  for i in 0..<cursor.line:
    result += self.lines[i].len + 1

proc tabWidth*(self: TextDocument): int =
  return self.languageConfig.map(c => c.tabWidth).get(4)

proc delete*(self: TextDocument, selections: openArray[Selection], oldSelection: openArray[Selection], notify: bool = true, record: bool = true, reparse: bool = true): seq[Selection] =
  result = self.clampAndMergeSelections selections

  var undoOp = UndoOp(kind: Nested, children: @[], oldSelection: @oldSelection)

  for i, selection in result:
    if selection.isEmpty:
      continue

    let selection = selection.normalized
    let (first, last) = selection

    let startByte = self.byteOffset(first)
    let endByte = self.byteOffset(last)

    let deletedText = self.contentString(selection)

    let firstColumnRune = self.lines[first.line].runeIndex(first.column)
    let lastColumnRune = self.lines[last.line].runeIndex(last.column)

    if first.line == last.line:
      # Single line selection
      self.lines[last.line].delete first.column..<last.column
    else:
      # Multi line selection
      # Delete from first cursor to end of first line and add last line
      if first.column < self.lastValidIndex first.line:
        self.lines[first.line].delete(first.column..<(self.lineLength first.line))
      self.lines[first.line].add self.lines[last.line][last.column..^1]
      # Delete all lines in between
      self.lines.delete (first.line + 1)..last.line

    result[i] = selection.first.toSelection
    for k in (i+1)..result.high:
      result[k] = result[k].subtract(selection)

    if not self.tsParser.isNil:
      # debugf"delete {startByte}, {endByte}, {first.column}, {last.column}, {firstColumnRune}, {lastColumnRune}"
      # debugf"delete1 {startByte}, {endByte}, {startByte}, {first.column}, {last.column}, {first.column}"
      # debugf"delete2 {startByte}, {endByte}, {startByte}, {firstColumnRune.int}, {lastColumnRune.int}, {firstColumnRune.int}"
      let edit = TSInputEdit(
        startIndex: startByte,
        oldEndIndex: endByte,
        newEndIndex: startByte,
        startPosition: TSPoint(row: selection.first.line, column: first.column),
        oldEndPosition: TSPoint(row: selection.last.line, column: last.column),
        newEndPosition: TSPoint(row: selection.first.line, column: first.column),
      )
      discard self.currentTree.edit(edit)

    inc self.version

    if record:
      undoOp.children.add UndoOp(kind: Insert, cursor: selection.first, text: deletedText)

    if notify:
      self.textDeleted.invoke((self, selection))

  if reparse:
    self.reparseTreesitter()

  if notify:
    self.notifyTextChanged()

  if record and undoOp.children.len > 0:
    self.undoOps.add undoOp
    self.redoOps = @[]

proc getNodeRange*(self: TextDocument, selection: Selection, parentIndex: int = 0, siblingIndex: int = 0): Option[Selection] =
  result = Selection.none
  if self.currentTree.isNil:
    return

  let rang = tsRange(tsPoint(selection.first, self.lines[selection.first.line].toOpenArray), tsPoint(selection.last, self.lines[selection.last.line].toOpenArray))
  var node = self.currentTree.root.descendantForRange rang

  for i in 0..<parentIndex:
    if node == self.currentTree.root:
      break
    node = node.parent

  for i in 0..<siblingIndex:
    if node.next.getSome(sibling):
      node = sibling
    else:
      break

  for i in siblingIndex..<0:
    if node.prev.getSome(sibling):
      node = sibling
    else:
      break

  result = node.getRange.toSelection(self.lines).some

proc firstNonWhitespace*(str: string): int =
  result = 0
  for c in str:
    if c != ' ':
      break
    result += 1

proc lastNonWhitespace*(str: string): int =
  result = str.high
  while result >= 0:
    if str[result] != ' ' and str[result] != '\t':
      break
    result -= 1

proc getIndentForLine*(self: TextDocument, line: int): int =
  return self.lines[line].firstNonWhitespace

proc traverse*(line, column: int, text: openArray[char]): (int, int) =
  var line = line
  var column = column
  for rune in text:
    if rune == '\n':
      inc line
      column = 0
    else:
      inc column

  return (line, column)

proc insert*(self: TextDocument, selections: openArray[Selection], oldSelection: openArray[Selection], texts: openArray[string], notify: bool = true, record: bool = true, reparse: bool = true): seq[Selection] =
  result = self.clampAndMergeSelections selections

  var undoOp = UndoOp(kind: Nested, children: @[], oldSelection: @oldSelection)

  for i, selection in result:
    let text = if texts.len == 1:
      texts[0]
    elif texts.len == result.len:
      texts[i]
    else:
      texts[min(i, texts.high)]

    let oldCursor = selection.last
    var cursor = selection.last
    let startByte = self.byteOffset(cursor)

    let lastColumnRune = self.lines[oldCursor.line].toOpenArray.runeIndex(oldCursor.column)
    var cursorColumnRune = self.lines[cursor.line].toOpenArray.runeIndex(cursor.column)

    var lineCounter: int = 0
    # echo "insert ", cursor, ": ", text
    if self.singleLine:
      let text = text.replace("\n", " ")
      if self.lines.len == 0:
        self.lines.add text
      else:
        self.lines[0].insert(text, cursor.column)
      cursor.column += text.len
      cursorColumnRune += text.runeLen

    else:
      for line in text.splitLines(false):
        defer: inc lineCounter
        if lineCounter > 0:
          # Split line
          self.lines.insert(self.lines[cursor.line][cursor.column..^1], cursor.line + 1)

          if cursor.column < self.lastValidIndex cursor.line:
            self.lines[cursor.line].delete(cursor.column..<(self.lineLength cursor.line))
          cursor = (cursor.line + 1, 0)

        if line.len > 0:
          self.lines[cursor.line].insert(line, cursor.column)
          cursor.column += line.len
          cursorColumnRune += line.runeLen

    result[i] = cursor.toSelection
    for k in (i+1)..result.high:
      result[k] = result[k].add((oldCursor, cursor))

    if not self.tsParser.isNil:
      let (end_line, end_column) = traverse(oldCursor.line, oldCursor.column, text)
      # debugf"insert {startByte} + {text.len} = {(startByte + text.len)}, {oldCursor.column}, {cursor.column}, {lastColumnRune}, {cursorColumnRune}"
      # debugf"insert1 {startByte}, {startByte}, {(startByte + text.len)}, {oldCursor.column}, {oldCursor.column}, {cursorColumnRune.int}"
      # debugf"insert1 {startByte}, {startByte}, {(startByte + text.len)}, {oldCursor.column}, {oldCursor.column}, {end_column}"
      # debugf"insert1 {startByte}, {startByte}, {(startByte + text.len)}, {lastColumnRune.int}, {lastColumnRune.int}, {cursorColumnRune.int}"
      let edit = TSInputEdit(
        startIndex: startByte,
        oldEndIndex: startByte,
        newEndIndex: startByte + text.len,
        startPosition: TSPoint(row: oldCursor.line, column: oldCursor.column),
        oldEndPosition: TSPoint(row: oldCursor.line, column: oldCursor.column),
        newEndPosition: TSPoint(row: cursor.line, column: end_column),
      )
      discard self.currentTree.edit(edit)

    inc self.version

    if record:
      undoOp.children.add UndoOp(kind: Delete, selection: (oldCursor, cursor))

    if notify:
      self.textInserted.invoke((self, oldCursor, text))

  if reparse:
    self.reparseTreesitter()

  if notify:
    self.notifyTextChanged()

  if record and undoOp.children.len > 0:
    self.undoOps.add undoOp
    self.redoOps = @[]

proc edit*(self: TextDocument, selections: openArray[Selection], oldSelection: openArray[Selection], texts: openArray[string], notify: bool = true, record: bool = true, reparse: bool = true): seq[Selection] =
  let selections = selections.map (s) => s.normalized
  result = self.delete(selections, oldSelection, false, record=record, reparse=false)
  result = self.insert(result, oldSelection, texts, record=record, reparse=false)

  if reparse:
    self.reparseTreesitter()

proc doUndo(self: TextDocument, op: UndoOp, oldSelection: openArray[Selection], useOldSelection: bool, redoOps: var seq[UndoOp], reparse: bool = true): seq[Selection] =
  case op.kind:
  of Delete:
    let text = self.contentString(op.selection)
    result = self.delete([op.selection], op.oldSelection, record=false, reparse=false)
    redoOps.add UndoOp(kind: Insert, cursor: op.selection.first, text: text, oldSelection: @oldSelection)

  of Insert:
    let selections = self.insert([op.cursor.toSelection], op.oldSelection, [op.text], record=false, reparse=false)
    result = selections
    redoOps.add UndoOp(kind: Delete, selection: (op.cursor, selections[0].last), oldSelection: @oldSelection)

  of Nested:
    result = op.oldSelection

    var redoOp = UndoOp(kind: Nested, oldSelection: @oldSelection)
    for i in countdown(op.children.high, 0):
      discard self.doUndo(op.children[i], oldSelection, useOldSelection, redoOp.children, reparse=false)

    redoOps.add redoOp

  if reparse:
    self.reparseTreesitter()

  if useOldSelection:
    result = op.oldSelection

proc undo*(self: TextDocument, oldSelection: openArray[Selection], useOldSelection: bool): Option[seq[Selection]] =
  result = seq[Selection].none

  if self.undoOps.len == 0:
    return

  let op = self.undoOps.pop
  return self.doUndo(op, oldSelection, useOldSelection, self.redoOps).some

proc doRedo(self: TextDocument, op: UndoOp, oldSelection: openArray[Selection], useOldSelection: bool, undoOps: var seq[UndoOp], reparse: bool = true): seq[Selection] =
  case op.kind:
  of Delete:
    let text = self.contentString(op.selection)
    result = self.delete([op.selection], op.oldSelection, record=false, reparse=false)
    undoOps.add UndoOp(kind: Insert, cursor: op.selection.first, text: text, oldSelection: @oldSelection)

  of Insert:
    result = self.insert([op.cursor.toSelection], [op.cursor.toSelection], [op.text], record=false, reparse=false)
    undoOps.add UndoOp(kind: Delete, selection: (op.cursor, result[0].last), oldSelection: @oldSelection)

  of Nested:
    result = op.oldSelection

    var undoOp = UndoOp(kind: Nested, oldSelection: @oldSelection)
    for i in countdown(op.children.high, 0):
      discard self.doRedo(op.children[i], oldSelection, useOldSelection, undoOp.children, reparse=false)

    undoOps.add undoOp

  if reparse:
    self.reparseTreesitter()

  if useOldSelection:
    result = op.oldSelection

proc redo*(self: TextDocument, oldSelection: openArray[Selection], useOldSelection: bool): Option[seq[Selection]] =
  result = seq[Selection].none

  if self.redoOps.len == 0:
    return

  let op = self.redoOps.pop
  return self.doRedo(op, oldSelection, useOldSelection, self.undoOps).some

proc isLineEmptyOrWhitespace*(self: TextDocument, line: int): bool =
  if line > self.lines.high:
    return false
  return self.lines[line].isEmptyOrWhitespace

proc isLineCommented*(self: TextDocument, line: int): bool =
  if line > self.lines.high or self.languageConfig.isNone or self.languageConfig.get.lineComment.isNone:
    return false
  return custom_unicode.strip(self.lines[line], trailing=false).startsWith(self.languageConfig.get.lineComment.get)

proc getLineCommentRange*(self: TextDocument, line: int): Selection =
  if line > self.lines.high or self.languageConfig.isNone or self.languageConfig.get.lineComment.isNone:
    return (line, 0).toSelection

  let prefix = self.languageConfig.get.lineComment.get
  let index = self.lines[line].find(prefix)
  if index == -1:
    return (line, 0).toSelection

  return ((line, index), (line, index + prefix.len))

proc toggleLineComment*(self: TextDocument, selections: Selections): seq[Selection] =
  result = selections

  if self.languageConfig.isNone:
    return

  if self.languageConfig.get.lineComment.isNone:
    return

  let mergedSelections = self.clampAndMergeSelections(selections).mergeLines

  var allCommented = true
  for s in mergedSelections:
    for l in s.first.line..s.last.line:
      if not self.isLineEmptyOrWhitespace(l):
        allCommented = allCommented and self.isLineCommented(l)

  let comment = not allCommented

  var insertSelections: Selections
  for s in mergedSelections:
    var minIndent = int.high
    for l in s.first.line..s.last.line:
      if not self.isLineEmptyOrWhitespace(l):
        minIndent = min(minIndent, self.getIndentForLine(l))

    for l in s.first.line..s.last.line:
      if not self.isLineEmptyOrWhitespace(l):
        if comment:
          insertSelections.add (l, minIndent).toSelection
        else:
          insertSelections.add self.getLineCommentRange(l)

  if comment:
    let prefix = self.languageConfig.get.lineComment.get
    discard self.insert(insertSelections, selections, [prefix])
  else:
    discard self.delete(insertSelections, selections)

proc trimTrailingWhitespace*(self: TextDocument) =
  var selections: seq[Selection]
  for i in 0..self.lines.high:
    let index = self.lines[i].lastNonWhitespace
    if index == self.lines[i].high:
      continue
    selections.add ((i, index + 1), (i, self.lines[i].len))
  discard self.delete(selections, selections)
