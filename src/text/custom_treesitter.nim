import std/[options, json]
import misc/[custom_logger, custom_async, util, custom_unicode]
import platform/filesystem

from scripting_api import Cursor, Selection, byteIndexToCursor

logCategory "treesitter"

when defined(js):
  import std/[asyncjs]

  type TSLanguage* {.importc("Language").} = ref object
    discard

  type TSParser* {.importc("Parser").} = ref object of RootObj
    discard

  type TSQuery* {.importc("Query").} = ref object of RootObj
    discard

  type TsTree* {.importc("Tree").} = ref object of RootObj
    discard

  type TSNode* {.importc("Node").} = ref object of RootObj
    discard

  type TSPoint* {.importc("Point").} = ref object of RootObj
    row*: int
    column*: int

  type TSRange* = object of RootObj
    first*: TSPoint
    last*: TSPoint

  type TSQueryCapture* {.importc("QueryCapture").} = ref object of RootObj
    discard

  type TSQueryMatch* {.importc("QueryMatch").} = ref object of RootObj
    discard

  type TSPredicateResultOperand* = ref object of RootObj
    name*: cstring
    `type`*: cstring

  type TSPredicateResult* {.importc("PredicateResult").} = ref object of RootObj
    discard

  type TSInputEdit* {.importc("Edit").} = ref object of RootObj
    startIndex*: int
    oldEndIndex*: int
    newEndIndex*: int
    startPosition*: TSPoint
    oldEndPosition*: TSPoint
    newEndPosition*: TSPoint

  proc jsLoadTreesitterLanguage(wasmPath: cstring): Future[TSLanguage] {.importc.}

  var treeSitterInitialized {.importc.}: bool

  proc isTreesitterInitialized*(): bool = treeSitterInitialized

  proc newTsParser*(): TSParser {.importcpp: "new Parser()".}
  proc setTimeoutMicros*(parser: TSParser, micros: int) {.importcpp: "#.setTimeoutMicros(#)".}
  proc setLanguage*(self: TSParser, language: TSLanguage) {.importcpp("#.setLanguage(#)").}
  proc query*(self: TSLanguage, source: string): TSQuery =
    proc queryJs(self: TSLanguage, source: cstring): TSQuery {.importcpp("#.query(#)").}
    return queryJs(self, source.cstring)
  proc parse*(self: TSParser, text: string, oldTree: TSTree = nil): TSTree {.importcpp("#.parse(#, #)").}
  proc parse*(self: TSParser, text: proc(index: int, position: TSPoint): string, oldTree: TSTree = nil): TSTree {.importcpp("#.parse(#, #)").}
  proc parseString*(self: TSParser, text: string, oldTree: Option[TSTree] = TSTree.none): TSTree =
    return self.parse(text, oldTree.get(nil))

  proc parseCallback*(self: TSParser, text: proc(index: int, position: TSPoint): string, oldTree: Option[TSTree] = TSTree.none): TSTree =
    return self.parse(text, oldTree.get(nil))

  proc root*(self: TSTree): TSNode {.importcpp("#.rootNode").}

  proc deleteJs(self: TSTree) {.importcpp("#.delete()").}
  proc delete*(self: var TSTree) =
    if self.isNotNil:
      deleteJs(self)
    self = nil

  proc matchesJs(self: TSQuery, node: TSNode, first, last: TSPoint): seq[TSQueryMatch] {.importcpp("#.matches(#, #, #)").}
  proc matches*(self: TSQuery, node: TSNode, rang: TSRange): seq[TSQueryMatch] =
    return self.matchesJs(node, rang.first, rang.last)

  proc predicatesForPattern*(self: TSQuery, patternIndex: int): seq[TSPredicateResult] {.importcpp("#.predicatesForPattern(#)").}

  proc name*(self: TSQueryCapture): cstring {.importcpp("#.name").}
  proc node*(self: TSQueryCapture): TSNode {.importcpp("#.node").}

  proc pattern*(self: TSQueryMatch): int {.importcpp("#.pattern").}
  proc captures*(self: TSQueryMatch): seq[TSQueryCapture] {.importcpp("#.captures").}

  proc operator*(self: TSPredicateResult): cstring {.importcpp("#.operator").}
  proc operands*(self: TSPredicateResult): seq[TSPredicateResultOperand] {.importcpp("#.operands").}

  proc `$`*(node: TSNode): string =
    proc toString(node: TSNode): cstring {.importcpp("#.toString()").}
    return $node.toString

  proc startPosition(node: TSNode): TSPoint {.importcpp("#.startPosition").}
  proc endPosition(node: TSNode): TSPoint {.importcpp("#.endPosition").}

  proc startPoint*(node: TSNode): TSPoint = node.startPosition
  proc endPoint*(node: TSNode): TSPoint = node.endPosition
  proc getRange*(node: TSNode): TSRange = TSRange(first: node.startPoint, last: node.endPoint)

  func toTsPoint*(cursor: Cursor, line: openArray[char]): TSPoint = TSPoint(row: cursor.line, column: cursor.column) #line.runeIndex(cursor.column))

  proc parent*(node: TSNode): TSNode {.importcpp("#.parent").}
  proc nextSibling(node: TSNode): TSNode {.importcpp("#.nextSibling").}
  proc previousSibling(node: TSNode): TSNode {.importcpp("#.previousSibling").}
  proc next*(node: TSNode): Option[TSNode] =
    let s = node.nextSibling
    if not s.isNil:
      return s.some
  proc prev*(node: TSNode): Option[TSNode] =
    let s = node.previousSibling
    if not s.isNil:
      return s.some

  proc descendantForRangeJs(node: TSNode, startPoint: TSPoint, endPoint: TSPoint): TSNode {.importcpp("#.descendantForPosition(#, #)").}
  proc descendantForRange*(node: TSNode, rang: TSRange): TSNode = node.descendantForRangeJs(rang.first, rang.last)

  proc edit*(self: TSTree, edit: TSInputEdit): TSTree {.importcpp("#.edit(#)").}

else:
  import std/dynlib
  import treesitter/api as ts

  import compilation_config

  when useBuiltinTreesitterLanguage("nim"):
    import treesitter_nim/treesitter_nim/nim
  when useBuiltinTreesitterLanguage("cpp"):
    import treesitter_cpp/treesitter_cpp/cpp
  when useBuiltinTreesitterLanguage("zig"):
    import treesitter_zig/treesitter_zig/zig
  when useBuiltinTreesitterLanguage("agda"):
    import treesitter_agda/treesitter_agda/agda
  when useBuiltinTreesitterLanguage("bash"):
    import treesitter_bash/treesitter_bash/bash
  when useBuiltinTreesitterLanguage("c"):
    import treesitter_c/treesitter_c/c
  when useBuiltinTreesitterLanguage("csharp"):
    import treesitter_c_sharp/treesitter_c_sharp/c_sharp
  when useBuiltinTreesitterLanguage("css"):
    import treesitter_css/treesitter_css/css
  when useBuiltinTreesitterLanguage("go"):
    import treesitter_go/treesitter_go/go
  when useBuiltinTreesitterLanguage("haskell"):
    import treesitter_haskell/treesitter_haskell/haskell
  when useBuiltinTreesitterLanguage("html"):
    import treesitter_html/treesitter_html/html
  when useBuiltinTreesitterLanguage("java"):
    import treesitter_java/treesitter_java/java
  when useBuiltinTreesitterLanguage("javascript"):
    import treesitter_javascript/treesitter_javascript/javascript
  when useBuiltinTreesitterLanguage("ocaml"):
    import treesitter_ocaml/treesitter_ocaml/ocaml
  when useBuiltinTreesitterLanguage("php"):
    import treesitter_php/treesitter_php/php
  when useBuiltinTreesitterLanguage("python"):
    import treesitter_python/treesitter_python/python
  when useBuiltinTreesitterLanguage("ruby"):
    import treesitter_ruby/treesitter_ruby/ruby
  when useBuiltinTreesitterLanguage("rust"):
    import treesitter_rust/treesitter_rust/rust
  when useBuiltinTreesitterLanguage("scala"):
    import treesitter_scala/treesitter_scala/scala
  when useBuiltinTreesitterLanguage("typescript"):
    import treesitter_typescript/treesitter_typescript/typescript

  type TSLanguage* = ref object
    impl: ptr ts.TSLanguage

  type TSParser* = ref object
    impl: ptr ts.TSParser

  type TSQuery* = ref object
    impl: ptr ts.TSQuery

  type TsTree* = ref object
    impl: ptr ts.TSTree

  type TSNode* = object
    impl: ts.TSNode

  type TSQueryCapture* = object
    name*: string
    node*: TSNode

  type TSQueryMatch* = ref object
    pattern*: int
    captures*: seq[TSQueryCapture]

  type TSPredicateResultOperand* = object
    name*: string
    `type`*: string

  type TSPredicateResult* = object
    operator*: string
    operands*: seq[TSPredicateResultOperand]

  type TSPoint* = object
    row*: int
    column*: int

  type TSRange* = object of RootObj
    first*: TSPoint
    last*: TSPoint

  type TSInputEdit* = object
    startIndex*: int
    oldEndIndex*: int
    newEndIndex*: int
    startPosition*: TSPoint
    oldEndPosition*: TSPoint
    newEndPosition*: TSPoint

  type TSLanguageCtor = proc(): ptr ts.TSLanguage {.stdcall.}

  func setLanguage*(self: TSParser, language: TSLanguage) =
    assert ts.tsParserSetLanguage(self.impl, language.impl)

  proc delete*(self: var TSTree) =
    if self.isNotNil:
      ts.tsTreeDelete(self.impl)
    self = nil

  proc query*(self: TSLanguage, source: string): TSQuery =
    var errorOffset: uint32 = 0
    var queryError: ts.TSQueryError = ts.TSQueryErrorNone
    result = TSQuery(impl: self.impl.tsQueryNew(source.cstring, source.len.uint32, addr errorOffset, addr queryError))
    if queryError != ts.TSQueryErrorNone:
      log(lvlError, fmt"Failed to load highlights query: {errorOffset} {source.byteIndexToCursor(errorOffset.int)}: {queryError}: {source}")
      return nil

  proc parseString*(self: TSParser, text: string, oldTree: Option[TSTree] = TSTree.none): TSTree =
    let oldTreePtr: ptr ts.TSTree = if oldTree.getSome(tree):
      tree.impl
    else:
      nil
    let tree = self.impl.tsParserParseString(oldTreePtr, text.cstring, text.len.uint32)
    if tree.isNil:
      return nil
    return TSTree(impl: tree)

  when not declared(c_malloc):
    proc c_malloc(size: csize_t): pointer {.importc: "malloc", header: "<stdlib.h>", used.}
    proc c_free(p: pointer): void {.importc: "free", header: "<stdlib.h>", used.}

  func toTsPoint*(cursor: Cursor, line: openArray[char]): ts.TSPoint = ts.TSPoint(row: cursor.line.uint32, column: line.runeIndex(cursor.column).uint32)
  func toTsPoint*(point: TSPoint): ts.TSPoint = ts.TSPoint(row: point.row.uint32, column: point.column.uint32)
  proc len*(node: TSNode): int = node.impl.tsNodeChildCount().int
  proc high*(node: TSNode): int = node.len - 1
  proc low*(node: TSNode): int = 0
  proc startByte*(node: TSNode): int = node.impl.tsNodeStartByte.int
  proc endByte*(node: TSNode): int = node.impl.tsNodeEndByte.int
  proc startPoint*(node: TSNode): TSPoint =
    let point = node.impl.tsNodeStartPoint
    return TSPoint(row: point.row.int, column: point.column.int)
  proc endPoint*(node: TSNode): TSPoint =
    let point = node.impl.tsNodeEndPoint
    return TSPoint(row: point.row.int, column: point.column.int)
  proc getRange*(node: TSNode): TSRange = TSRange(first: node.startPoint, last: node.endPoint)

  proc root*(tree: TSTree): TSNode = TSNode(impl: tree.impl.tsTreeRootNode)
  proc edit*(self: TSTree, edit: TSInputEdit): TSTree =
    var tsEdit = ts.TSInputEdit(
      startByte: edit.startIndex.uint32,
      oldEndByte: edit.oldEndIndex.uint32,
      newEndByte: edit.newEndIndex.uint32,
      startPoint: edit.startPosition.toTsPoint,
      oldEndPoint: edit.oldEndPosition.toTsPoint,
      newEndPoint: edit.newEndPosition.toTsPoint,
    )
    self.impl.tsTreeEdit(addr tsEdit)
    return self

  proc execute*(cursor: ptr ts.TSQueryCursor, query: TSQuery, node: TSNode) = cursor.tsQueryCursorExec(query.impl, node.impl)
  proc prev*(node: TSNode): Option[TSNode] =
    let other = node.impl.tsNodePrevSibling
    if not other.tsNodeIsNull:
      result = TSNode(impl: other).some
  proc next*(node: TSNode): Option[TSNode] =
    let other = node.impl.tsNodeNextSibling
    if not other.tsNodeIsNull:
      result = TSNode(impl: other).some
  proc prevNamed*(node: TSNode): Option[TSNode] =
    let other = node.impl.tsNodePrevNamedSibling
    if not other.tsNodeIsNull:
      result = TSNode(impl: other).some
  proc nextNamed*(node: TSNode): Option[TSNode] =
    let other = node.impl.tsNodeNextNamedSibling
    if not other.tsNodeIsNull:
      result = TSNode(impl: other).some

  proc `[]`*(node: TSNode, index: int): TSNode = TSNode(impl: node.impl.tsNodeChild(index.uint32))
  proc descendantForRange*(node: TSNode, rang: TSRange): TSNode = TSNode(impl: ts.tsNodeDescendantForPointRange(node.impl, rang.first.toTsPoint, rang.last.toTsPoint))
  proc parent*(node: TSNode): TSNode = TSNode(impl: node.impl.tsNodeParent())
  proc `==`*(a: TSNode, b: TSNode): bool = a.impl.tsNodeEq(b.impl)
  proc current*(cursor: var ts.TSTreeCursor): ts.TSNode = tsTreeCursorCurrentNode(addr cursor)
  proc gotoParent*(cursor: var ts.TSTreeCursor): bool = tsTreeCursorGotoParent(addr cursor)
  proc gotoNextSibling*(cursor: var ts.TSTreeCursor): bool = tsTreeCursorGotoNextSibling(addr cursor)
  proc gotoFirstChild*(cursor: var ts.TSTreeCursor): bool = tsTreeCursorGotoFirstChild(addr cursor)
  # proc gotoFirstChildForCursor*(cursor: var ts.TSTreeCursor, cursor2: Cursor): int = tsTreeCursorGotoFirstChildForPoint(addr cursor, cursor2.toTsPoint).int

  proc setPointRange*(cursor: ptr ts.TSQueryCursor, rang: TSRange) =
    cursor.tsQueryCursorSetPointRange(rang.first.toTsPoint, rang.last.toTsPoint)

  proc getCaptureName*(query: TSQuery, index: uint32): string =
    var length: uint32
    var str = ts.tsQueryCaptureNameForId(query.impl, index, addr length)
    defer: assert result.len == length.int
    return $str

  proc getStringValue*(query: TSQuery, index: uint32): string =
    var length: uint32
    var str = ts.tsQueryStringValueForId(query.impl, index, addr length)
    defer: assert result.len == length.int
    return $str

  proc nextMatch(cursor: ptr ts.TSQueryCursor, query: TSQuery): Option[ts.TSQueryMatch] =
    result = ts.TSQueryMatch.none
    var match: ts.TSQueryMatch
    if cursor.tsQueryCursorNextMatch(addr match):
      result = match.some

  proc nextCapture*(cursor: ptr ts.TSQueryCursor): Option[tuple[match: ts.TSQueryMatch, captureIndex: int]] =
    var match: ts.TSQueryMatch
    var index: uint32
    if cursor.tsQueryCursorNextCapture(addr match, addr index):
      result = (match, index.int).some

  proc `$`*(node: ts.TSNode): string =
    # debugf"$node: {node.context}, {(cast[uint64](node.id)):x}, {(cast[uint64](node.tree)):x}"
    let c_str = node.tsNodeString()
    defer: c_str.c_free
    result = $c_str

  template withQueryCursor*(cursor: untyped, body: untyped): untyped =
    bind tsQueryCursorNew
    bind tsQueryCursorDelete
    block:
      let cursor = ts.tsQueryCursorNew()
      defer: ts.tsQueryCursorDelete(cursor)
      body

  template withTreeCursor*(node: untyped, cursor: untyped, body: untyped): untyped =
    bind tsTreeCursorNew
    bind tsTreeCursorDelete
    block:
      let cursor = ts.tsTreeCursorNew(node)
      defer: ts.tsTreeCursorDelete(cursor)
      body

  var scratchQueryCursor: ptr ts.TSQueryCursor = nil

  proc matches*(self: TSQuery, node: TSNode, rang: TSRange): seq[TSQueryMatch] =
    result = @[]

    if scratchQueryCursor.isNil:
      scratchQueryCursor = ts.tsQueryCursorNew()
    let cursor = scratchQueryCursor

    cursor.setPointRange rang
    cursor.execute(self, node)

    var match = cursor.nextMatch(self)
    while match.isSome:
      var m = TSQueryMatch(pattern: match.get.patternIndex.int)
      let capturesRaw = cast[ptr array[100000, ts.TSQueryCapture]](match.get.captures)
      for k in 0..<match.get.capture_count.int:
        m.captures.add(TSQueryCapture(name: self.getCaptureName(capturesRaw[k].index), node: TSNode(impl: capturesRaw[k].node)))

      result.add m
      match = cursor.nextMatch(self)

    for m in result:
      for c in m.captures:
        assert not c.node.impl.id.isNil
        assert not c.node.impl.tree.isNil

  proc predicatesForPattern*(self: TSQuery, patternIndex: int): seq[TSPredicateResult] =
    var predicatesLength: uint32 = 0
    let predicatesPtr = ts.tsQueryPredicatesForPattern(self.impl, patternIndex.uint32, addr predicatesLength)
    let predicatesRaw = cast[ptr array[100000, ts.TSQueryPredicateStep]](predicatesPtr)

    result = @[]

    var argIndex = 0
    var predicateName: string = ""
    var predicateArgs: seq[string] = @[]

    for k in 0..<predicatesLength:
      case predicatesRaw[k].`type`:
      of ts.TSQueryPredicateStepTypeString:
        let value = self.getStringValue(predicatesRaw[k].valueId)
        if argIndex == 0:
          predicateName = value
        else:
          predicateArgs.add value
        argIndex += 1

      of ts.TSQueryPredicateStepTypeCapture:
        predicateArgs.add self.getCaptureName(predicatesRaw[k].valueId)
        argIndex += 1

      of ts.TSQueryPredicateStepTypeDone:
        if predicateArgs.len mod 2 == 0:
          var predicateOperands: seq[TSPredicateResultOperand] = @[]
          for i in 0..<(predicateArgs.len div 2):
            predicateOperands.add TSPredicateResultOperand(name: predicateArgs[i * 2], `type`: predicateArgs[i * 2 + 1])
          result.add (TSPredicateResult(operator: predicateName, operands: predicateOperands))
        predicateName = ""
        predicateArgs.setLen 0
        argIndex = 0


# Available on all targets

when not defined(js):
  import std/[tables]
  var treesitterDllCache = initTable[string, LibHandle]()

  import std/macros

proc loadLanguageDynamically*(languageId: string, config: JsonNode): Future[Option[TSLanguage]] {.async.} =
  when defined(js):
    try:
      let wasmPath = if config.hasKey("wasm"):
        config["wasm"].getStr
      else:
        fmt"languages/tree-sitter-{languageId}.wasm"

      log(lvlInfo, fmt"Trying to load treesitter from '{wasmPath}'")
      let language = await jsLoadTreesitterLanguage(wasmPath.cstring)
      if language.isNil:
        return TSLanguage.none
      return language.some
    except CatchableError:
      log(lvlError, fmt"Failed to load language from wasm: '{languageId}': {getCurrentExceptionMsg()}")
      return TSLanguage.none

  else:
    try:
      let ctorSymbolName = if config.hasKey("constructor"):
        config["constructor"].getStr
      else:
        fmt"tree_sitter_{languageId}"

      const fileExtension = when defined(windows):
        "dll"
      else:
        "so"

      let dllPath = if config.hasKey("path"):
        config["path"].getStr
      else:
        fmt"./languages/{languageId}.{fileExtension}"

      let absolutePath = fs.getApplicationFilePath(dllPath)

      log(lvlInfo, fmt"Trying to load treesitter from '{absolutePath}' using function '{ctorSymbolName}'")
      let lib = if treesitterDllCache.contains(absolutePath):
        treesitterDllCache[absolutePath]
      else:
        let lib = loadLib(absolutePath)
        if lib.isNil:
          log(lvlError, fmt"Failed to load treesitter dll for '{languageId}': '{absolutePath}'")
          return TSLanguage.none
        treesitterDllCache[absolutePath] = lib
        lib

      let ctor = cast[TSLanguageCtor](lib.symAddr(ctorSymbolName.cstring))
      if ctor.isNil:
        log(lvlError, fmt"Failed to load treesitter dll for '{languageId}': '{absolutePath}'")
        return TSLanguage.none

      let tsLanguage = ctor()
      if tsLanguage.isNil:
        log(lvlError, fmt"Failed to create language from dll '{languageId}': '{absolutePath}'")
        return TSLanguage.none

      return TSLanguage(impl: tsLanguage).some
    except CatchableError:
      log(lvlError, fmt"Failed to load language from dll: '{languageId}': {getCurrentExceptionMsg()}")
      return TSLanguage.none

proc loadLanguage*(languageId: string, config: JsonNode): Future[Option[TSLanguage]] {.async.} =
  let language = await loadLanguageDynamically(languageId, config)
  if language.isSome:
    return language

  when defined(js):
    return TSLanguage.none
  else:
    log(lvlInfo, fmt"No dll language for {languageId}, try builtin")


    macro nameof(t: untyped): untyped =
      return t.repr.newLit

    template tryGetLanguage(constructor: untyped): untyped =
      block:
        var l: Option[TSLanguage] = TSLanguage.none
        when compiles(constructor()):
          static:
            echo "Including builtin treesitter language '", nameof(constructor), "'"
          log lvlInfo, fmt"Loading builtin language"
          l = TSLanguage(impl: constructor()).some
        l

    return case languageId
    of "agda": tryGetLanguage(treeSitterAgda)
    of "c": tryGetLanguage(treeSitterC)
    of "bash": tryGetLanguage(treeSitterBash)
    of "csharp": tryGetLanguage(treeSitterCSharp)
    of "cpp": tryGetLanguage(treeSitterCpp)
    of "css": tryGetLanguage(treeSitterCss)
    of "go": tryGetLanguage(treeSitterGo)
    of "haskell": tryGetLanguage(treeSitterHaskell)
    of "html": tryGetLanguage(treeSitterHtml)
    of "java": tryGetLanguage(treeSitterJava)
    of "javascript": tryGetLanguage(treeSitterJavascript)
    of "ocaml": tryGetLanguage(treeSitterOcaml)
    of "php": tryGetLanguage(treeSitterPhp)
    of "python": tryGetLanguage(treeSitterPython)
    of "ruby": tryGetLanguage(treeSitterRuby)
    of "rust": tryGetLanguage(treeSitterRust)
    of "scala": tryGetLanguage(treeSitterScala)
    of "typescript": tryGetLanguage(treeSitterTypecript)
    of "nim": tryGetLanguage(treeSitterNim)
    of "zig": tryGetLanguage(treeSitterZig)
    else:
      log(lvlWarn, fmt"Failed to init treesitter for language '{languageId}'")
      TSLanguage.none

proc createTsParser*(): TSParser =
  when defined(js):
    result = newTsParser()
    result.setTimeoutMicros(1_000_000)
  else:
    return TSParser(impl: ts.tsParserNew())

proc deinit*(self: TSParser) =
  when not defined(js):
    self.impl.tsParserDelete()

proc deinit*(self: TSQuery) =
  when not defined(js):
    self.impl.tsQueryDelete()

proc tsPoint*(line: int, column: RuneIndex, text: openArray[char]): TSPoint = TSPoint(row: line, column: text.runeOffset(column))
proc tsPoint*(line: int, column: int): TSPoint = TSPoint(row: line, column: column)
proc tsPoint*(cursor: Cursor): TSPoint = TSPoint(row: cursor.line, column: cursor.column)
proc tsRange*(first: TSPoint, last: TSPoint): TSRange = TSRange(first: first, last: last)
proc tsRange*(selection: scripting_api.Selection): TSRange = TSRange(first: tsPoint(selection.first), last: tsPoint(selection.last))
proc toCursor*(point: TSPoint): Cursor = (point.row, point.column)
proc toSelection*(rang: TSRange): scripting_api.Selection = (rang.first.toCursor, rang.last.toCursor)

proc freeDynamicLibraries*() =
  when not defined(js):
    for (path, lib) in treesitterDllCache.pairs:
      lib.unloadLib()
    treesitterDllCache.clear()
