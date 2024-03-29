import std/[strformat, tables, sugar, sequtils, strutils, algorithm, math, options, json]
import vmath, bumpy, chroma
import misc/[util, custom_logger, custom_unicode, myjsonutils]
import text/text_editor
import scripting_api except DocumentEditor, TextDocumentEditor, AstDocumentEditor
import platform/platform
import ui/[widget_builders_base, widget_library]
import app, document_editor, theme, config_provider, app_interface
import text/language/[lsp_types]

import ui/node

# Mark this entire file as used, otherwise we get warnings when importing it but only calling a method
{.used.}

logCategory "widget_builder_text"

type CursorLocationInfo* = tuple[node: UINode, text: string, bounds: Rect, original: Cursor]
type LocationInfos = object
  cursor: Option[CursorLocationInfo]
  hover: Option[CursorLocationInfo]
  diagnostic: Option[CursorLocationInfo]

when defined(js):
  template tokenColor*(theme: Theme, part: StyledText, default: untyped): Color =
    theme.tokenColor(part.scopeC, default)
else:
  template tokenColor*(theme: Theme, part: StyledText, default: untyped): Color =
    theme.tokenColor(part.scope, default)

proc shouldIgnoreAsContextLine(self: TextDocument, line: int): bool
proc clampToLine(document: TextDocument, selection: Selection, line: StyledLine): tuple[first: RuneIndex, last: RuneIndex]

proc `*`(c: Color, v: Color): Color {.inline.} =
  ## Multiply color by a value.
  result.r = c.r * v.r
  result.g = c.g * v.g
  result.b = c.b * v.b
  result.a = c.a * v.a

proc getCursorPos(self: TextDocumentEditor, textRuneLen: int, line: int, startOffset: RuneIndex, pos: Vec2): int =
  var offsetFromLeft = pos.x / self.platform.charWidth
  if self.isThickCursor():
    offsetFromLeft -= 0.0
  else:
    offsetFromLeft += 0.5

  let index = clamp(offsetFromLeft.int, 0, textRuneLen)
  let byteIndex = self.document.lines[line].toOpenArray.runeOffset(startOffset + index.RuneCount)
  return byteIndex

proc renderLine*(
  self: TextDocumentEditor, builder: UINodeBuilder, theme: Theme,
  line: StyledLine, lineOriginal: openArray[char],
  lineId: int32, parentId: Id, cursorLine: int,
  lineNumber: int, lineNumbers: LineNumbers,
  y: float, sizeToContentX: bool, lineNumberTotalWidth: float, lineNumberWidth: float, pivot: Vec2,
  backgroundColor: Color, textColor: Color,
  backgroundColors: openArray[tuple[first: RuneIndex, last: RuneIndex, color: Color]], cursors: openArray[int],
  wrapLine: bool, wrapLineEndChar: string, wrapLineEndColor: Color, lineEndColor: Option[Color]):
    tuple[cursors: seq[CursorLocationInfo], hover: Option[CursorLocationInfo], diagnostic: Option[CursorLocationInfo]] =

  var flagsInner = &{FillX, SizeToContentY}
  if sizeToContentX:
    flagsInner.incl SizeToContentX

  let hasDiagnostic = self.diagnosticsPerLine.contains(lineNumber) and self.diagnosticsPerLine[lineNumber][0] < self.document.currentDiagnostics.len
  let diagnosticIndices = if hasDiagnostic:
    self.diagnosticsPerLine[lineNumber]
  else:
    @[]
  var diagnosticColorName = "editorHint.foreground"
  var diagnosticMessage: string = "■ "
  if hasDiagnostic:
    let diagnostic {.cursor.} = self.document.currentDiagnostics[diagnosticIndices[0]]
    diagnosticMessage.add diagnostic.message[0..min(diagnostic.message.high, 300)]

    if diagnostic.severity.getSome(severity):
      diagnosticColorName = case severity
      of Error: "editorError.foreground"
      of Warning: "editorWarning.foreground"
      of Information: "editorInfo.foreground"
      of Hint: "editorHint.foreground"

  let diagnosticMessageLen = diagnosticMessage.runeLen
  let diagnosticLines = diagnosticMessage.countLines
  let diagnosticMessageWidth = diagnosticMessageLen.float * builder.charWidth

  # line numbers
  var lineNumberText = ""
  var lineNumberX = 0.float
  if lineNumbers != LineNumbers.None and cursorLine == lineNumber:
    lineNumberText = $(lineNumber + 1)
  elif lineNumbers == LineNumbers.Absolute:
    lineNumberText = $(lineNumber + 1)
    lineNumberX = max(0.0, lineNumberWidth - lineNumberText.len.float * builder.charWidth)
  elif lineNumbers == LineNumbers.Relative:
    lineNumberText = $abs((lineNumber + 1) - cursorLine)
    lineNumberX = max(0.0, lineNumberWidth - lineNumberText.len.float * builder.charWidth)

  builder.panel(flagsInner + LayoutVertical + FillBackground, y = y, pivot = pivot, backgroundColor = backgroundColor, userId = newSecondaryId(parentId, lineId)):
    let lineWidth = currentNode.bounds.w

    var subLine: UINode = nil

    var start = 0
    var lastPartXW: float32 = 0
    var partIndex = 0
    var subLineIndex = 0
    var subLinePartIndex = 0
    var previousInlayNode: UINode = nil
    var insertDiagnosticLater: bool = false
    while partIndex < line.parts.len or insertDiagnosticLater: # outer loop for wrapped lines within this line

      builder.panel(flagsInner + LayoutHorizontal):
        subLine = currentNode

        if lineNumberText.len > 0:
          builder.panel(&{UINodeFlag.FillBackground, FillY}, w = lineNumberTotalWidth, backgroundColor = backgroundColor):
            if subLineIndex == 0:
              builder.panel(&{DrawText, SizeToContentX, SizeToContentY}, text = lineNumberText, x = lineNumberX, textColor = textColor)
          lastPartXW = lineNumberTotalWidth

        while partIndex < line.parts.len: # inner loop for parts within a wrapped line part
          template part: StyledText = line.parts[partIndex]

          let partRuneLen = part.text.runeLen
          let width = (partRuneLen.float * builder.charWidth).ceil

          if wrapLine and not sizeToContentX and subLinePartIndex > 0:
            var wrapWidth = width
            for partIndex2 in partIndex..<line.parts.high:
              if line.parts[partIndex2].joinNext:
                let nextWidth = (line.parts[partIndex2 + 1].text.runeLen.float * builder.charWidth).ceil
                if lineNumberTotalWidth + wrapWidth + nextWidth + builder.charWidth <= lineWidth:
                  wrapWidth += nextWidth
                  continue
              break

            if lastPartXW + wrapWidth + builder.charWidth >= lineWidth:
              builder.panel(&{DrawText, FillBackground, SizeToContentX, SizeToContentY}, text = wrapLineEndChar, backgroundColor = backgroundColor, textColor = wrapLineEndColor):
                defer:
                  lastPartXW = currentNode.xw
              subLineIndex += 1
              subLinePartIndex = 0
              break

          let textColor = if part.scope.len == 0: textColor else: theme.tokenColor(part, textColor)

          var startRune = 0.RuneIndex
          var endRune = 0.RuneIndex
          if part.textRange.isSome:
            startRune = part.textRange.get.startIndex
            endRune = part.textRange.get.endIndex
          else:
            # Inlay text, find start rune of neighbor, prefer left side
            var found = false
            for i in countdown(partIndex - 1, 0):
              if line.parts[i].textRange.isSome:
                startRune = line.parts[i].textRange.get.endIndex
                found = true
                break

            if not found:
              for i in countup(partIndex + 1, line.parts.high):
                if line.parts[i].textRange.isSome:
                  startRune = line.parts[i].textRange.get.startIndex
                  break

            endRune = startRune

          # Find background color
          var colorIndex = 0
          while colorIndex < backgroundColors.high and (backgroundColors[colorIndex].first == backgroundColors[colorIndex].last or backgroundColors[colorIndex].last <= startRune):
            inc colorIndex

          var partBackgroundColor = backgroundColor
          var addBackgroundAsChildren = true

          # check if fully covered by background color (inlay text is always fully covered by background color)
          if part.textRange.isNone or backgroundColors[colorIndex].last >= startRune + partRuneLen:
            partBackgroundColor = backgroundColors[colorIndex].color
            addBackgroundAsChildren = false

          var partFlags = &{UINodeFlag.FillBackground, SizeToContentX, SizeToContentY, MouseHover}

          # if the entire part is the same background color we can just fill the background and render the text on the part itself
          # otherwise we need to render the background as a separate node and render the text on top of it, as children of the main part node,
          # which still has a background color though
          if not addBackgroundAsChildren:
            partFlags.incl DrawText
          else:
            partFlags.incl OverlappingChildren

          let text = if addBackgroundAsChildren: "" else: part.text
          let textRuneLen = part.text.runeLen.int

          let isInlay = part.textRange.isNone

          var partNode: UINode
          builder.panel(partFlags, text = text, backgroundColor = partBackgroundColor, textColor = textColor):
            partNode = currentNode

            capture line, partNode, startRune, textRuneLen, isInlay:
              onClickAny btn:
                self.lastPressedMouseButton = btn
                if btn == Left:
                  let offset = self.getCursorPos(textRuneLen, line.index, startRune, if isInlay: vec2() else: pos)
                  self.selection = (line.index, offset).toSelection
                  self.dragStartSelection = self.selection
                  self.runSingleClickCommand()
                  self.updateTargetColumn(Last)
                  self.app.tryActivateEditor(self)
                  self.markDirty()
                elif btn == DoubleClick:
                  let offset = self.getCursorPos(textRuneLen, line.index, startRune, if isInlay: vec2() else: pos)
                  self.selection = (line.index, offset).toSelection
                  self.dragStartSelection = self.selection
                  self.runDoubleClickCommand()
                  self.updateTargetColumn(Last)
                  self.app.tryActivateEditor(self)
                  self.markDirty()
                elif btn == TripleClick:
                  let offset = self.getCursorPos(textRuneLen, line.index, startRune, if isInlay: vec2() else: pos)
                  self.selection = (line.index, offset).toSelection
                  self.dragStartSelection = self.selection
                  self.runTripleClickCommand()
                  self.updateTargetColumn(Last)
                  self.app.tryActivateEditor(self)
                  self.markDirty()

              onDrag Left:
                if self.active:
                  let offset = self.getCursorPos(textRuneLen, line.index, startRune, if isInlay: vec2() else: pos)
                  let currentSelection = self.dragStartSelection
                  let newCursor = (line.index, offset)
                  let first = if (currentSelection.isBackwards and newCursor <= currentSelection.first) or (not currentSelection.isBackwards and newCursor >= currentSelection.first):
                    currentSelection.first
                  else:
                    currentSelection.last
                  self.selection = (first, newCursor)
                  self.runDragCommand()
                  self.updateTargetColumn(Last)
                  self.app.tryActivateEditor(self)
                  self.markDirty()

              onBeginHover:
                let offset = self.getCursorPos(textRuneLen, line.index, startRune, pos)
                self.lastHoverLocationBounds = partNode.boundsAbsolute.some
                self.showHoverForDelayed (line.index, offset)

              onHover:
                let offset = self.getCursorPos(textRuneLen, line.index, startRune, pos)
                self.lastHoverLocationBounds = partNode.boundsAbsolute.some
                self.showHoverForDelayed (line.index, offset)

              onEndHover:
                self.hideHoverDelayed()

            if addBackgroundAsChildren:
              # Add separate background colors for selections/highlights
              while colorIndex <= backgroundColors.high and backgroundColors[colorIndex].first < startRune + partRuneLen:
                let x = max(0.0, backgroundColors[colorIndex].first.float - startRune.float) * builder.charWidth
                let xw = min(partRuneLen.float, backgroundColors[colorIndex].last.float - startRune.float) * builder.charWidth
                if partBackgroundColor != backgroundColors[colorIndex].color:
                  builder.panel(&{UINodeFlag.FillBackground, FillY}, x = x, w = xw - x, backgroundColor = backgroundColors[colorIndex].color)

                inc colorIndex

              # Add text on top of background colors
              builder.panel(&{DrawText, SizeToContentX, SizeToContentY}, text = part.text, textColor = textColor)

            # cursor
            for curs in cursors:
              let selectionLastRune = lineOriginal.runeIndex(curs)

              if part.textRange.isSome:
                if selectionLastRune >= part.textRange.get.startIndex and selectionLastRune < part.textRange.get.endIndex:
                  let node = if selectionLastRune == startRune and previousInlayNode.isNotNil:
                    # show cursor on first position of previous inlay
                    previousInlayNode
                  else:
                    partNode
                  let cursorX = builder.textWidth(int(selectionLastRune - part.textRange.get.startIndex.RuneCount)).round
                  let rune = part.text[selectionLastRune - part.textRange.get.startIndex.RuneCount]
                  result.cursors.add (node, $rune, rect(cursorX, 0, builder.charWidth, builder.textHeight), (line.index, curs))

            # Set hover info if the hover location is within this part
            if line.index == self.hoverLocation.line and part.textRange.isSome:
              let startRune = part.textRange.get.startIndex
              let endRune = part.textRange.get.endIndex
              let hoverRune = lineOriginal.runeIndex(self.hoverLocation.column)
              if hoverRune >= startRune and hoverRune < endRune:
                result.hover = (currentNode, "", rect(0, 0, builder.charWidth, builder.textHeight), self.hoverLocation).some

          if part.textRange.isNone:
            previousInlayNode = partNode
          else:
            previousInlayNode = nil

          lastPartXW = partNode.bounds.xw
          start += part.text.len
          partIndex += 1
          subLinePartIndex += 1

        var insertDiagnosticNow = false
        if hasDiagnostic and partIndex >= line.parts.len:
          insertDiagnosticNow = true
          let diagnosticXOffset = 7 * builder.charWidth
          for i in 0..0:
            insertDiagnosticLater = false
            if diagnosticXOffset + diagnosticMessageWidth > lineWidth - lastPartXW:
              if subLinePartIndex > 0:
                subLineIndex += 1
                subLinePartIndex = 0
                insertDiagnosticLater = true
                insertDiagnosticNow = false
                break

        # Fill rest of line with background
        let lineEndYFlags = if insertDiagnosticNow: &{SizeToContentY} else: &{FillY}
        builder.panel(&{FillX, FillBackground} + lineEndYFlags, backgroundColor = backgroundColor):
          capture line, currentNode:
            onClickAny btn:
              self.lastPressedMouseButton = btn
              if btn == Left:
                self.selection = (line.index, self.document.lineLength(line.index)).toSelection
                self.dragStartSelection = self.selection
                self.app.tryActivateEditor(self)
                self.runSingleClickCommand()
                self.updateTargetColumn(Last)
                self.markDirty()
              elif btn == DoubleClick:
                self.selection = (line.index, self.document.lineLength(line.index)).toSelection
                self.dragStartSelection = self.selection
                self.runDoubleClickCommand()
                self.updateTargetColumn(Last)
                self.app.tryActivateEditor(self)
                self.markDirty()
              elif btn == TripleClick:
                self.selection = (line.index, self.document.lineLength(line.index)).toSelection
                self.dragStartSelection = self.selection
                self.runTripleClickCommand()
                self.updateTargetColumn(Last)
                self.app.tryActivateEditor(self)
                self.markDirty()

            onDrag Left:
              if self.active:
                let currentSelection = self.dragStartSelection
                let newCursor = (line.index, self.document.lineLength(line.index))
                let first = if (currentSelection.isBackwards and newCursor < currentSelection.first) or (not currentSelection.isBackwards and newCursor >= currentSelection.first):
                  currentSelection.first
                else:
                  currentSelection.last
                self.selection = (first, newCursor)
                self.runDragCommand()
                self.updateTargetColumn(Last)
                self.app.tryActivateEditor(self)
                self.markDirty()

          if insertDiagnosticNow:
            let diagnosticXOffset = 7 * builder.charWidth
            let diagnosticColor = theme.color(@[diagnosticColorName, "editor.foreground"], color(1, 1, 1))
            var diagnosticPanel: UINode = nil
            let diagnosticHeight = diagnosticLines.float * builder.textHeight
            builder.panel(&{DrawText, FillBackground, SizeToContentX, MaskContent},
              x = diagnosticXOffset, h = diagnosticHeight, text = diagnosticMessage, textColor = diagnosticColor, backgroundColor = backgroundColor.lighten(0.07)):
              diagnosticPanel = currentNode

          if lineEndColor.getSome(color):
            builder.panel(&{FillY, FillBackground}, w = builder.charWidth, backgroundColor = color)

        if self.showDiagnostic and self.currentDiagnosticLine == lineNumber:
          result.diagnostic = (currentNode, "", rect(0, 0, builder.charWidth, builder.textHeight), (0, 0)).some

    # cursor after latest char
    for curs in cursors:
      if curs == lineOriginal.len:
        result.cursors.add (subLine, "", rect(lastPartXW, 0, builder.charWidth, builder.textHeight), (line.index, curs))

    # set hover info if the hover location is at the end of this line
    if line.index == self.hoverLocation.line and self.hoverLocation.column == lineOriginal.len:
      result.hover = (subLine, "", rect(lastPartXW, 0, builder.charWidth, builder.textHeight), self.hoverLocation).some

proc blendColorRanges(colors: var seq[tuple[first: RuneIndex, last: RuneIndex, color: Color]], ranges: var seq[tuple[first: RuneIndex, last: RuneIndex]], color: Color, inclusive: bool) =
  let inclusiveOffset = if inclusive: 1.RuneCount else: 0.RuneCount
  for s in ranges.mitems:
    var colorIndex = 0
    for i in 0..colors.high:
      if colors[i].last > s.first:
        colorIndex = i
        break

    while colorIndex <= colors.high and colors[colorIndex].last > s.first and colors[colorIndex].first < s.last + inclusiveOffset and s.first != s.last + inclusiveOffset:
      let lastIndex = colors[colorIndex].last
      colors[colorIndex].last = s.first

      if lastIndex < s.last + inclusiveOffset:
        colors.insert (s.first, lastIndex, colors[colorIndex].color.blendNormal(color)), colorIndex + 1
        s.first = lastIndex
        inc colorIndex
      else:
        colors.insert (s.first, s.last + inclusiveOffset, colors[colorIndex].color.blendNormal(color)), colorIndex + 1
        colors.insert (s.last + inclusiveOffset, lastIndex, colors[colorIndex].color), colorIndex + 2
        break

      inc colorIndex

proc blendColorRanges(colors: var seq[tuple[first: RuneIndex, last: RuneIndex, color: Color]], ranges: var seq[tuple[first: RuneIndex, last: RuneIndex, color: Color]], inclusive: bool) =
  let inclusiveOffset = if inclusive: 1.RuneCount else: 0.RuneCount
  for s in ranges.mitems:
    var colorIndex = 0
    for i in 0..colors.high:
      if colors[i].last > s.first:
        colorIndex = i
        break

    while colorIndex <= colors.high and colors[colorIndex].last > s.first and colors[colorIndex].first < s.last + inclusiveOffset and s.first != s.last + inclusiveOffset:
      let lastIndex = colors[colorIndex].last
      colors[colorIndex].last = s.first

      if lastIndex < s.last + inclusiveOffset:
        colors.insert (s.first, lastIndex, colors[colorIndex].color.blendNormal(s.color)), colorIndex + 1
        s.first = lastIndex
        inc colorIndex
      else:
        colors.insert (s.first, s.last + inclusiveOffset, colors[colorIndex].color.blendNormal(s.color)), colorIndex + 1
        colors.insert (s.last + inclusiveOffset, lastIndex, colors[colorIndex].color), colorIndex + 2
        break

      inc colorIndex

proc createTextLines(self: TextDocumentEditor, builder: UINodeBuilder, app: App, backgroundColor: Color, textColor: Color, sizeToContentX: bool, sizeToContentY: bool): LocationInfos =
  var flags = 0.UINodeFlags
  if sizeToContentX:
    flags.incl SizeToContentX
  else:
    flags.incl FillX

  if sizeToContentY:
    flags.incl SizeToContentY
  else:
    flags.incl FillY

  let inclusive = getOption[bool](app, "editor.text.inclusive-selection", false)

  let lineNumbers = self.lineNumbers.get getOption[LineNumbers](app, "editor.text.line-numbers", LineNumbers.Absolute)
  let charWidth = builder.charWidth

  # ↲ ↩ ⤦ ⤶ ⤸ ⮠
  let wrapLineEndChar = getOption[string](app, "editor.text.wrap-line-end-char", "↲")
  let wrapLines = getOption[bool](app, "editor.text.wrap-lines", true)
  let showContextLines = getOption[bool](app, "editor.text.context-lines", true)

  let selectionColor = app.theme.color("selection.background", color(200/255, 200/255, 200/255))
  let highlightColor = app.theme.color(@["editor.findMatchBackground", "editor.rangeHighlightBackground"], color(200/255, 200/255, 200/255))
  let cursorForegroundColor = app.theme.color(@["editorCursor.foreground", "foreground"], color(200/255, 200/255, 200/255))
  let cursorBackgroundColor = app.theme.color(@["editorCursor.background", "background"], color(50/255, 50/255, 50/255))
  let contextBackgroundColor = app.theme.color(@["breadcrumbPicker.background", "background"], color(50/255, 70/255, 70/255))
  let wrapLineEndColor = app.theme.tokenColor(@["comment"], color(100/255, 100/255, 100/255))

  var selectionsPerLine = initTable[int, seq[Selection]]()
  for s in self.selections:
    let sn = s.normalized
    for line in sn.first.line..sn.last.line:
      selectionsPerLine.mgetOrPut(line, @[]).add s

  # var highlightsPerLine = self.searchResults
  # var highlightsPerLine = self.searchResults

  # builder.panel(&{FillX, LayoutVertical}, flags += (if sizeToContentY: &{SizeToContentY} else: &{FillY})):
  builder.panel(flags + MaskContent + OverlappingChildren):
    let linesPanel = currentNode

    let height = currentNode.bounds.h

    # line numbers
    let maxLineNumber = case lineNumbers
      of LineNumbers.Absolute: self.previousBaseIndex + ((height - self.scrollOffset) / builder.textHeight).int
      of LineNumbers.Relative: 99
      else: 0
    let maxLineNumberLen = ($maxLineNumber).len + 1
    let cursorLine = self.selection.last.line

    let lineNumberPadding = charWidth
    let lineNumberBounds = if lineNumbers != LineNumbers.None:
      vec2(maxLineNumberLen.float32 * charWidth, 0)
    else:
      vec2()

    let lineNumberWidth = if lineNumbers != LineNumbers.None:
      (lineNumberBounds.x + lineNumberPadding).ceil
    else:
      0.0

    var cursors: seq[CursorLocationInfo]
    var contextLines: seq[int]
    var contextLineTarget: int = -1
    var hoverInfo = CursorLocationInfo.none
    var diagnosticInfo = CursorLocationInfo.none

    proc handleScroll(delta: float) =
      self.scrollText(delta * app.asConfigProvider.getValue("text.scroll-speed", 40.0))

    proc handleLine(i: int, y: float, down: bool) =
      let styledLine = self.getStyledText i
      let totalLineHeight = builder.textHeight

      self.lastRenderedLines.add styledLine

      var indexFromTop = if down:
        (y / totalLineHeight + 0.5).ceil.int
      else:
        (y / totalLineHeight - 0.5).ceil.int

      indexFromTop -= 1

      let indentLevel = self.document.getIndentLevelForClosestLine(i)

      var wrapLine = wrapLines
      var i = i
      var backgroundColor = backgroundColor
      if showContextLines and (indexFromTop <= indentLevel and not self.document.shouldIgnoreAsContextLine(i)):
        contextLineTarget = max(contextLineTarget, i)

      proc parseColor(str: string): Color = app.theme.color(str, color(200/255, 200/255, 200/255))

      # selections and highlights
      var selectionsClampedOnLine = selectionsPerLine.getOrDefault(i, @[]).map (s) => self.document.clampToLine(s.normalized, styledLine)
      var highlightsClampedOnLine: seq[tuple[first: RuneIndex, last: RuneIndex, color: Color]] =
        self.customHighlights.getOrDefault(i, @[]).map (s) => (let x = self.document.clampToLine(s.selection.normalized, styledLine); (x[0], x[1], parseColor(s.color) * s.tint))

      selectionsClampedOnLine.sort((a, b) => cmp(a.first, b.first), Ascending)
      highlightsClampedOnLine.sort((a, b) => cmp(a.first, b.first), Ascending)

      var colors: seq[tuple[first: RuneIndex, last: RuneIndex, color: Color]] = @[(0.RuneIndex, self.document.lines[i].runeLen.RuneIndex, backgroundColor.withAlpha(1))]
      blendColorRanges(colors, highlightsClampedOnLine, inclusive)
      blendColorRanges(colors, selectionsClampedOnLine, selectionColor, inclusive)

      var cursorsPerLine: seq[int]
      for s in self.selections:
        if s.last.line == i:
          cursorsPerLine.add s.last.column

      var lineEndColor = Color.none
      if self.document.lines[i].len == 0 and selectionsClampedOnLine.len > 0 and (cursorsPerLine.len == 0 or inclusive):
        lineEndColor = selectionColor.some

      let pivot = if down:
        vec2(0, 0)
      else:
        vec2(0, 1)

      let infos = self.renderLine(builder, app.theme, styledLine, self.document.lines[i], self.document.lineIds[i],
        self.userId, cursorLine, i, lineNumbers, y, sizeToContentX, lineNumberWidth, lineNumberBounds.x, pivot,
        backgroundColor, textColor,
        colors, cursorsPerLine, wrapLine, wrapLineEndChar, wrapLineEndColor, lineEndColor
        )
      cursors.add infos.cursors
      if infos.hover.isSome:
        hoverInfo = infos.hover
      if infos.diagnostic.isSome:
        diagnosticInfo = infos.diagnostic

    self.lastRenderedLines.setLen 0
    builder.createLines(self.previousBaseIndex, self.scrollOffset, self.document.lines.high, sizeToContentX, sizeToContentY, backgroundColor, handleScroll, handleLine)

    # context lines
    if contextLineTarget >= 0:
      var indentLevel = self.document.getIndentLevelForClosestLine(contextLineTarget)
      while indentLevel > 0 and contextLineTarget > 0:
        contextLineTarget -= 1
        let newIndentLevel = self.document.getIndentLevelForClosestLine(contextLineTarget)
        if newIndentLevel < indentLevel and not self.document.shouldIgnoreAsContextLine(contextLineTarget):
          contextLines.add contextLineTarget
          indentLevel = newIndentLevel

      contextLines.sort(Ascending)

      if contextLines.len > 0:
        for indexFromTop, contextLine in contextLines:
          let styledLine = self.getStyledText contextLine
          let y = indexFromTop.float * builder.textHeight
          let colors = [(first: 0.RuneIndex, last: self.document.lines[contextLine].runeLen.RuneIndex, color: contextBackgroundColor)]

          let infos = self.renderLine(builder, app.theme, styledLine, self.document.lines[contextLine], self.document.lineIds[contextLine],
            self.userId, cursorLine, contextLine, lineNumbers, y, sizeToContentX, lineNumberWidth, lineNumberBounds.x, vec2(0, 0),
            contextBackgroundColor, textColor,
            colors, [], false, wrapLineEndChar, wrapLineEndColor, Color.none
            )
          cursors.add infos.cursors
          if infos.hover.isSome:
            result.hover = infos.hover

        # let fill = self.scrollOffset mod builder.textHeight
        # if fill < builder.textHeight / 2:
        #   builder.panel(&{FillX, FillBackground}, y = contextLines.len.float * builder.textHeight, h = fill, backgroundColor = contextBackgroundColor)

    let isThickCursor = self.isThickCursor

    if hoverInfo.isSome:
      result.hover = hoverInfo
    if diagnosticInfo.isSome:
      result.diagnostic = diagnosticInfo

    for cursorIndex, cursorLocation in cursors: #cursor
      if cursorLocation.original == self.selection.last:
        result.cursor = cursorLocation.some

      var bounds = cursorLocation.bounds.transformRect(cursorLocation.node, linesPanel) - vec2(app.platform.charGap, 0)
      bounds.w += app.platform.charGap

      if not isThickCursor:
        bounds.w = 0.2 * app.platform.charWidth

      if not self.cursorVisible:
        bounds.w = 0

      builder.panel(&{UINodeFlag.FillBackground, AnimatePosition, MaskContent}, x = bounds.x, y = bounds.y, w = bounds.w, h = bounds.h, backgroundColor = cursorForegroundColor, userId = newSecondaryId(self.cursorsId, cursorIndex.int32)):
        if isThickCursor:
          builder.panel(&{DrawText, SizeToContentX, SizeToContentY}, x = app.platform.charGap, y = 0, text = cursorLocation.text, textColor = cursorBackgroundColor)

    defer:
      self.lastContentBounds = currentNode.bounds

proc createHover(self: TextDocumentEditor, builder: UINodeBuilder, app: App, cursorBounds: Rect) =
  let totalLineHeight = app.platform.totalLineHeight
  let charWidth = app.platform.charWidth

  let backgroundColor = app.theme.color(@["editorHoverWidget.background", "panel.background"], color(30/255, 30/255, 30/255))
  let borderColor = app.theme.color(@["editorHoverWidget.border", "focusBorder"], color(30/255, 30/255, 30/255))
  let docsColor = app.theme.color("editor.foreground", color(1, 1, 1))

  let numLinesToShow = min(10, self.hoverText.countLines)
  let (top, bottom) = (cursorBounds.yh.float, cursorBounds.yh.float + totalLineHeight * numLinesToShow.float)
  let height = bottom - top

  const docsWidth = 50.0
  let totalWidth = charWidth * docsWidth
  var clampedX = cursorBounds.x
  if clampedX + totalWidth > builder.root.w:
    clampedX = max(builder.root.w - totalWidth, 0)

  var hoverPanel: UINode = nil
  builder.panel(&{SizeToContentX, MaskContent, FillBackground, DrawBorder, MouseHover, SnapInitialBounds, AnimateBounds}, x = clampedX, y = top, h = height, pivot = vec2(0, 0), backgroundColor = backgroundColor, borderColor = borderColor, userId = self.hoverId.newPrimaryId):
    hoverPanel = currentNode
    var textNode: UINode = nil
    # todo: height
    builder.panel(&{DrawText, SizeToContentX}, x = 0, y = self.hoverScrollOffset, h = 1000, text = self.hoverText, textColor = docsColor):
      textNode = currentNode

    onScroll:
      let scrollSpeed = app.asConfigProvider.getValue("text.hover-scroll-speed", 20.0)
      # todo: clamp bottom
      self.hoverScrollOffset = clamp(self.hoverScrollOffset + delta.y * scrollSpeed, -1000, 0)
      self.markDirty()

    onBeginHover:
      self.cancelDelayedHideHover()

    onEndHover:
      self.hideHoverDelayed()

  hoverPanel.rawY = cursorBounds.y
  hoverPanel.pivot = vec2(0, 1)

proc createDiagnostics(self: TextDocumentEditor, builder: UINodeBuilder, app: App, cursorBounds: Rect, backgroundColor: Color) =
  let totalLineHeight = app.platform.totalLineHeight
  let charWidth = app.platform.charWidth

  let docsColorName = if self.currentDiagnostic.severity.getSome(severity):
    case severity
    of Error: "editorError.foreground"
    of Warning: "editorWarning.foreground"
    of Information: "editorInfo.foreground"
    of Hint: "editorHint.foreground"
  else:
    "editorHint.foreground"

  let docsColor = app.theme.color(@[docsColorName, "editor.foreground"], color(1, 1, 1))

  # todo
  return

  # var text = ""
  # # self.currentDiagnostic.message

  # let numLinesToShow = min(10, text.countLines)
  # let (top, bottom) = (cursorBounds.yh.float, cursorBounds.yh.float + totalLineHeight * numLinesToShow.float)
  # let height = bottom - top

  # const docsWidth = 50.0
  # let totalWidth = charWidth * docsWidth
  # var clampedX = cursorBounds.x
  # if clampedX + totalWidth > builder.root.w:
  #   clampedX = max(builder.root.w - totalWidth, 0)

  # var hoverPanel: UINode = nil
  # builder.panel(&{SizeToContentX, MaskContent, FillBackground, MouseHover, DrawBorder}, x = clampedX, y = top, h = height, backgroundColor = backgroundColor, userId = self.diagnosticsId.newPrimaryId):
  #   hoverPanel = currentNode
  #   var textNode: UINode = nil
  #   builder.panel(&{DrawText, SizeToContentX}, x = 0, h = 1000, text = text, textColor = docsColor):
  #     textNode = currentNode

  # # hoverPanel.rawX = hoverPanel.parent.bounds.w - hoverPanel.bounds.w
  # hoverPanel.rawY = cursorBounds.y
  # hoverPanel.pivot = vec2(0, 1)

proc createCompletions(self: TextDocumentEditor, builder: UINodeBuilder, app: App, cursorBounds: Rect) =
  let totalLineHeight = app.platform.totalLineHeight
  let charWidth = app.platform.charWidth

  let backgroundColor = app.theme.color(@["editorSuggestWidget.background", "panel.background"], color(30/255, 30/255, 30/255))
  let borderColor = app.theme.color(@["editorSuggestWidget.border", "panel.background"], color(30/255, 30/255, 30/255))
  let selectedBackgroundColor = app.theme.color(@["editorSuggestWidget.selectedBackground", "list.activeSelectionBackground"], color(200/255, 200/255, 200/255))
  let docsColor = app.theme.color(@["editorSuggestWidget.foreground", "editor.foreground"], color(1, 1, 1))
  let nameColor = app.theme.color(@["editorSuggestWidget.foreground", "editor.foreground"], color(1, 1, 1))
  let nameSelectedColor = app.theme.color(@["editorSuggestWidget.highlightForeground", "editor.foreground"], color(1, 1, 1))
  let scopeColor = app.theme.color(@["descriptionForeground", "editor.foreground"], color(175/255, 1, 175/255))

  const numLinesToShow = 20
  let (top, bottom) = (cursorBounds.yh.float, cursorBounds.yh.float + totalLineHeight * numLinesToShow)

  const listWidth = 120.0
  const docsWidth = 50.0
  const maxTypeLen = 50
  let totalWidth = charWidth * listWidth + charWidth * docsWidth
  var clampedX = cursorBounds.x
  if clampedX + totalWidth > builder.root.w:
    clampedX = max(builder.root.w - totalWidth, 0)

  updateBaseIndexAndScrollOffset(bottom - top, self.completionsBaseIndex, self.completionsScrollOffset, self.completionMatches.len, totalLineHeight, self.scrollToCompletion)
  self.scrollToCompletion = int.none

  var completionsPanel: UINode = nil
  builder.panel(&{SizeToContentX, SizeToContentY, AnimateBounds, MaskContent}, x = clampedX, y = top, w = totalWidth, h = bottom - top, pivot = vec2(0, 0), userId = self.completionsId.newPrimaryId):
    completionsPanel = currentNode

    proc handleScroll(delta: float) =
      let scrollAmount = delta * app.asConfigProvider.getValue("text.scroll-speed", 40.0)
      self.scrollOffset += scrollAmount
      self.markDirty()

    proc handleLine(i: int, y: float, down: bool) =
      var backgroundColor = backgroundColor
      if i == self.selectedCompletion:
        backgroundColor = selectedBackgroundColor

      backgroundColor.a = 1

      let pivot = if down:
        vec2(0, 0)
      else:
        vec2(0, 1)

      builder.panel(&{FillX, SizeToContentY, FillBackground}, y = y, pivot = pivot, backgroundColor = backgroundColor):
        let completion = self.completions.items[self.completionMatches[i].index]
        let color = if i == self.selectedCompletion: nameSelectedColor else: nameColor

        let matchIndices = self.getCompletionMatches(i)
        builder.highlightedText(completion.label, matchIndices, color, color.lighten(0.15))

        let detail = if completion.detail.getSome(detail):
          if detail.len < maxTypeLen:
            detail & " ".repeat(maxTypeLen - detail.len)
          else:
            detail[0..<(maxTypeLen - 3)] & "..."
        else:
          ""
        let filterText = completion.filterText.get("")
        let scopeText = detail
        builder.panel(&{DrawText, SizeToContentX, SizeToContentY}, x = currentNode.w, pivot = vec2(1, 0), text = scopeText, textColor = scopeColor)

    builder.panel(&{UINodeFlag.MaskContent, DrawBorder}, w = listWidth * charWidth, h = bottom - top, borderColor = borderColor):
      builder.createLines(self.completionsBaseIndex, self.completionsScrollOffset, self.completionMatches.high, false, false, backgroundColor, handleScroll, handleLine)

    if self.selectedCompletion >= 0 and self.selectedCompletion < self.completionMatches.len:
      var docText = ""
      if self.completions.items[self.completionMatches[self.selectedCompletion].index].detail.getSome(detail):
        docText = detail

      if self.completions.items[self.completionMatches[self.selectedCompletion].index].documentation.getSome(doc):
        if docText.len > 0:
          docText.add "\n\n"
        if doc.asString().getSome(doc):
          docText.add doc
        elif doc.asMarkupContent().getSome(markup):
          docText.add markup.value

      # if docText.len > 0:
      #   docText.add "\n\n"

      # block:
      #   var uiae = self.completions.items[self.completionMatches[self.selectedCompletion].index]
      #   uiae.documentation = CompletionItemDocumentationVariant.none
      #   docText.add uiae.toJson.pretty

      builder.panel(&{UINodeFlag.FillBackground, DrawText, MaskContent, TextWrap},
        x = listWidth * charWidth, w = docsWidth * charWidth, h = bottom - top,
        backgroundColor = backgroundColor, textColor = docsColor, text = docText)

  if completionsPanel.bounds.yh > completionsPanel.parent.bounds.h:
    completionsPanel.rawY = cursorBounds.y
    completionsPanel.pivot = vec2(0, 1)

method createUI*(self: TextDocumentEditor, builder: UINodeBuilder, app: App): seq[proc() {.closure.}] =
  self.preRender()

  let dirty = self.dirty
  self.resetDirty()

  let textColor = app.theme.color("editor.foreground", color(225/255, 200/255, 200/255))
  var backgroundColor = if self.active: app.theme.color("editor.background", color(25/255, 25/255, 40/255)) else: app.theme.color("editor.background", color(25/255, 25/255, 25/255)) * 0.85
  backgroundColor.a = 1

  var headerColor = if self.active: app.theme.color("tab.activeBackground", color(45/255, 45/255, 60/255)) else: app.theme.color("tab.inactiveBackground", color(45/255, 45/255, 45/255))
  headerColor.a = 1

  let sizeToContentX = SizeToContentX in builder.currentParent.flags
  let sizeToContentY = SizeToContentY in builder.currentParent.flags

  var sizeFlags = 0.UINodeFlags
  if sizeToContentX:
    sizeFlags.incl SizeToContentX
  else:
    sizeFlags.incl FillX

  if sizeToContentY:
    sizeFlags.incl SizeToContentY
  else:
    sizeFlags.incl FillY

  builder.panel(&{UINodeFlag.MaskContent, OverlappingChildren} + sizeFlags, userId = self.userId.newPrimaryId):
    onClickAny btn:
      self.app.tryActivateEditor(self)

    if not self.disableScrolling and not sizeToContentY:
      updateBaseIndexAndScrollOffset(currentNode.bounds.h, self.previousBaseIndex, self.scrollOffset, self.document.lines.len, builder.textHeight, int.none)

    if dirty or app.platform.redrawEverything or not builder.retain():
      var header: UINode

      builder.panel(&{LayoutVertical} + sizeFlags):
        header = builder.createHeader(self.renderHeader, self.currentMode, self.document, headerColor, textColor):
          onRight:
            proc cursorString(cursor: Cursor): string = $cursor.line & ":" & $cursor.column & ":" & $self.document.lines[cursor.line].toOpenArray.runeIndex(cursor.column)
            builder.panel(&{SizeToContentX, SizeToContentY, DrawText}, pivot = vec2(1, 0), textColor = textColor, text = fmt" {(cursorString(self.selection.first))}-{(cursorString(self.selection.last))} - {self.id} ")
        let infos = self.createTextLines(builder, app, backgroundColor, textColor, sizeToContentX, sizeToContentY)
        if infos.cursor.getSome(info):
          self.lastCursorLocationBounds = info.bounds.transformRect(info.node, builder.root).some
        if infos.hover.getSome(info):
          self.lastHoverLocationBounds = info.bounds.transformRect(info.node, builder.root).some
        if infos.diagnostic.getSome(info):
          self.lastDiagnosticLocationBounds = info.bounds.transformRect(info.node, builder.root).some

  if self.showCompletions and self.active:
    result.add proc() =
      self.createCompletions(builder, app, self.lastCursorLocationBounds.get(rect(100, 100, 10, 10)))

  if self.showHover:
    result.add proc() =
      self.createHover(builder, app, self.lastHoverLocationBounds.get(rect(100, 100, 10, 10)))

  if self.showDiagnostic and self.currentDiagnosticLine != -1:
    result.add proc() =
      self.createDiagnostics(builder, app, self.lastDiagnosticLocationBounds.get(rect(100, 100, 10, 10)), backgroundColor)

proc shouldIgnoreAsContextLine(self: TextDocument, line: int): bool =
  let indent = self.getIndentLevelForLine(line)
  return line > 0 and self.languageConfig.isSome and self.languageConfig.get.ignoreContextLinePrefix.isSome and
        self.lineStartsWith(line, self.languageConfig.get.ignoreContextLinePrefix.get, true) and self.getIndentLevelForLine(line - 1) == indent

proc clampToLine(document: TextDocument, selection: Selection, line: StyledLine): tuple[first: RuneIndex, last: RuneIndex] =
  result.first = if selection.first.line < line.index: 0.RuneIndex elif selection.first.line == line.index: document.lines[line.index].runeIndex(selection.first.column) else: line.runeLen.RuneIndex
  result.last = if selection.last.line < line.index: 0.RuneIndex elif selection.last.line == line.index: document.lines[line.index].runeIndex(selection.last.column) else: line.runeLen.RuneIndex
